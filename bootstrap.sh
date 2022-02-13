#!/bin/bash
#
usage() {
    cat << EOF >&2
Usage: $0 [--nosyspkgs] [--sysprefix] [-rprefix] [--rroot] [-h|--help]

--nosyspkgs: If passed, then do not install system packages (requires sudo
             access). Default=YES (install system packages).

--sysprefix <dir>: The directory to install ARGoS and other system dependencies
                   to. Default=$HOME/.local/system.

--rprefix <dir>: The directory to install research repositories
                 to. Default=$HOME/.local/.

--rroot <dir>: The root directory for all repos for the project. All github
               repos will be cloned/built in here. Default=$HOME/research.

--platform [ARGOS,ROS]: The platform you are bootstrapping stuff for.

-f|--force: Don't prompt before executing the bootstrap.

--env [devel,turtlebot]: The type of environment to setup. Default=turtlebot.

--opt: Optimized build

-h|--help: Show this message.
EOF
    exit 1
}

# Make sure script was not run as root or with sudo
if [ $(id -u) = 0 ]; then
    echo "This script cannot be run as root."
    exit 1
fi

install_sys_pkgs="YES"
sys_install_prefix=$HOME/.local/system
research_install_prefix=$HOME/.local
research_root=$HOME/research
platform=ARGOS
do_prompt="YES"
build_type="DEV"
env_type="devel"

options=$(getopt -o hf --long help,opt,nosyspkgs,force,sysprefix:,rprefix:,rroot:,platform:,env:  -n "BOOTSTRAP" -- "$@")
if [ $? != 0 ]; then usage; exit 1; fi

eval set -- "$options"
while true; do
    case "$1" in
        -h|--help) usage;;
        -f|--force) do_prompt="NO";;
        --nosyspkgs) install_sys_pkgs="NO";;
        --opt) build_type="OPT";;
        --sysprefix) sys_install_prefix=$2; shift;;
        --rprefix) research_install_prefix=$2; shift;;
        --rroot) research_root=$2; shift;;
        --platform) platform=$2; shift;;
        --env) env_type=$2; shift;;
        --) break;;
        *) break;;
    esac
    shift;
done

# set -x

################################################################################
# Functions
################################################################################
function bootstrap_main() {
    # Install system packages
    if [ "YES" = "$install_sys_pkgs" ]; then
        libra_pkgs_core=(make
                         cmake
                         git
                         ccache
                         gcc-9
                         g++-9
                         gcc-9-arm-linux-gnueabihf
                         g++-9-arm-linux-gnueabihf
                        )

        libra_pkgs_devel=(nodejs
                          npm
                          graphviz
                          doxygen
                          cppcheck
                          libclang-10-dev
                          clang-tools-10
                          clang-format-10
                          clang-tidy-10
                         )

        rcppsw_pkgs_core=(libboost-all-dev
                          liblog4cxx-dev
                          catch
                          python3-pip
                         )

        cosm_pkgs_core=(ros-noetic-ros-base
                       )

        cosm_pkgs_devel=(qtbase5-dev
                        libfreeimageplus-dev
                        freeglut3-dev
                        libeigen3-dev
                        libudev-dev
                        ros-noetic-desktop-full
                        liblua5.3-dev
                       )

        # Modern cmake required, default with most ubuntu versions is too
        # old--use kitware PPA.
        wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
        echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ focal main' | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
        sudo apt-get update

        # Install core packages (must be loop to ignore ones that don't exist).
        for pkg in "${libra_pkgs_core[@]} ${rcppsw_pkgs_core[@]} ${cosm_pkgs_core[@]}"
        do
            sudo apt-get -my install $pkg
        done

        if [ "$env_type" = "devel" ]; then
            # Install extra development packages (must be loop to ignore
            # ones that don't exist).
            for pkg in "${libra_pkgs_devel[@]} ${rcppsw_pkgs_devel[@]} ${cosm_pkgs_devel[@]}"
            do
                sudo apt-get -my install $pkg
            done
        fi
    fi



    if [ "$env_type" = "devel" ]; then
        python_pkgs_devel=(
            # RCPPSW packages
            cpplint
            breathe
            exhale
        )
        pip3 install --user  "${python_pkgs_devel[@]}"
    fi

    if [ "$platform" = "ROS" ]; then
        python_pkgs_core=(
            catkin_tools
        )
        pip3 install --user  "${python_pkgs_core[@]}"
    fi
    export PATH=$PATH:$HOME/.local/bin

    # Exit when any command after this fails. Can't be before the package
    # installs, because it is not an error if some of the packages are not found
    # (I just put a list of possible packages that might exist on debian systems
    # to satisfy project requirements).
    set -e

    # Now that all system packages are installed, build all repos
    bootstrap_dir=$(pwd)
    mkdir -p $research_root && cd $research_root

    er=$([ "OPT" = "$build_type" ] && echo "NONE" || echo "ALL")
    rcppsw_args=$([ "turtlebot" = "$env_type" ] && echo "-DRCPPSW_AL_MT_SAFE_TYPES=NO" || echo "")

    # Turtlebot actually has 4 cores, but not enough memory to be able
    # to do parallel compilation. 
    n_cores=$([ "turtlebot" = "$env_type" ] && echo "-DN_CORES=1" || echo "")

    cmake \
        -DPLATFORM=$platform \
        -DRESEARCH_DEPS_PREFIX=$sys_install_prefix \
        -DRESEARCH_INSTALL_PREFIX=$research_install_prefix \
        -DLIBRA_ER=$er \
        -DCMAKE_BUILD_TYPE=$build_type \
        $n_cores \
        $rcppsw_args \
        $bootstrap_dir

    make

    if [ "$platform" = "ROS" ]; then
        rm -rf $research_root/rosbridge
        mkdir -p $research_root/rosbridge && cd $research_root/rosbridge
         git clone -b devel https://github.com/swarm-robotics/sierra_rosbridge.git src/sierra_rosbridge
        git clone -b devel https://github.com/swarm-robotics/fordyca_rosbridge.git src/fordyca_rosbridge
        catkin init
        catkin config --extend /opt/ros/noetic --install --install-space=$research_install_prefix/ros
        catkin build
    fi

    # Made it!
    echo -e "********************************************************************************"
    echo -e "BOOTSTRAP SUCCESS!"
    echo -e "********************************************************************************"
}

function bootstrap_prompt() {

    echo -e "********************************************************************************"
    echo -e "Bootstrap Configuration Summary:"
    echo -e "********************************************************************************"
    echo -e ""
    echo -e ""
    echo -e "Install .deb packages                    : $install_sys_pkgs"
    echo -e "Clone repos to                           : $research_root"
    echo -e "Install compiled dependencies to         : $sys_install_prefix"
    echo -e "Install compiled research projects to    : $research_install_prefix"
    echo -e "Platform                                 : $platform"
    echo -e "Environment setup                        : $env_type"
    echo -e "Build type                               : $build_type"
    echo -e ""
    echo -e ""
    echo -e "********************************************************************************"

    while true; do
        echo "Please verify the above configuration."
        echo "WARNING: Anything in the installation directories may be overwritten!"
        read -p "Execute bootstrap (yes/no)? " yn

        case $yn in
            [Yy]* ) bootstrap_main; break;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

if [ "$do_prompt" = "YES" ]; then
    bootstrap_prompt
else
    bootstrap_main
fi
