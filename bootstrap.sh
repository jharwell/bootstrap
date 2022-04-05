#!/bin/bash
#
usage() {
    cat << EOF >&2
Usage: $0 [option]... [-h|--help]

--syspkgs: If passed, install system .deb packages (requires sudo
             access). Default=NO (don't install system packages).

--sysprefix <dir>: The directory to install ARGoS and other system dependencies
                   to. Default=$HOME/.local/system.

--rprefix <dir>: The directory to install research repositories
                 to. Default=$HOME/.local/.

--rroot <dir>: The root directory for all repos for the project. All github
               repos will be cloned/built in here. Default=$HOME/research.


--platform [ARGOS,ROS]: The platform you are bootstrapping stuff for.

--er [ALL,FATAL,NONE]: The level of event logging to enable. Default=ALL.

--opt: Optimized build (i.e., compile with optimizations on).

--branch: A <repo>:<branch> pair defining the branch which will be
  checked out for the specified repo.  Pass --branch multiple times to
  configure specific repos. Default=devel for all.

--env [DEVEL,MSI,ROBOT]: The type of build environment to bootstrap
  for. DEVEL sets up a standard development environment on the current
  machine. MSI sets up a "production" environment on the Minnesota
  Supercomputing Institute servers. ROBOT sets things up for a
  robot. Default=DEVEL.

  If --env=MSI, the following are also set:

     --opt
     --platform=ARGOS
     --robot=FOOTBOT

--robot [ETURTLEBOT3,FOOTBOT]: The type of robot to build for. FOOTBOT is the
  standard ARGoS foot-bot. ETURTLEBOT3 is the standard turtlebot3 burger,
  augmented with additional sensors to make it more useful. Default=FOOTBOT.

-f|--force: Don't prompt before executing the bootstrap (the configuration
 summary is still shown).

-h|--help: Show this message.
EOF
    exit 1
}

# Make sure script was not run as root or with sudo
if [ $(id -u) = 0 ]; then
    echo "This script cannot be run as root."
    exit 1
fi

install_sys_pkgs="NO"
sys_install_prefix=$HOME/.local/system
research_install_prefix=$HOME/.local
research_root=$HOME/research
platform="ARGOS"
do_prompt="YES"
build_type="DEV"
build_env="DEVEL"
robot="FOOTBOT"
er_level="ALL"
declare -A configured_branches=([rcsw]=devel
                                [rcppsw]=devel
                                [argos]=devel
                                [eepuck3D]=devel
                                [cosm]=devel
                                [fordyca]=devel
                                [sierra]=devel
                                [titerra]=devel
                                [fordyca_rosbridge]=devel
                                [sierra_rosbridge]=devel
                               )

options=$(getopt -o hf --long help,opt,syspkgs,force,sysprefix:,rprefix:,rroot:,platform:,env:,robot:,branch:,er:  -n "BOOTSTRAP" -- "$@")
if [ $? != 0 ]; then usage; exit 1; fi

eval set -- "$options"
while true; do
    case "$1" in
        -h|--help) usage;;
        -f|--force) do_prompt="NO";;
        --syspkgs) install_sys_pkgs="YES";;
        --opt) build_type="OPT";;
        --sysprefix) sys_install_prefix=$2; shift;;
        --rprefix) research_install_prefix=$2; shift;;
        --rroot) research_root=$2; shift;;
        --platform) platform=$2; shift;;
        --env) build_env=$2; shift;;
        --er) er_level=$2; shift;;
        --branch) branches=$2; shift;;
        --robot) robot=$2; shift;;
        --) break;;
        *) break;;
    esac
    shift;
done

# Set options when bootstraping on MSI
if [ "MSI" = "$build_env" ]; then
    if [ -z "${SWARMROOT}" ]; then
        . /home/gini/shared/swarm/bin/msi-env-setup.sh
    fi

    build_type="OPT"
    platform=ARGOS
    sys_install_prefix=$SWARMROOT/$MSIARCH
fi

# set -x

# Configure branches to checkout
declare -A branch_overrides;
for pair in ${branches[@]}; do
    IFS=':' read -ra PARSED <<< "$pair"
    branch_overrides[${PARSED[0]}]=${PARSED[1]}
done

for KEY in "${!branch_overrides[@]}";
do
    configured_branches[$KEY]=${branch_overrides[$KEY]};
done

################################################################################
# Main Functions
################################################################################
function install_packages() {
    # Install system packages
    #
    # Core pkgs=those needed in all build environments.
    # Devel pkgs=those only needed for development.
    if [ "YES" = "$install_sys_pkgs" ]; then
        libra_pkgs_core=(make
                         cmake
                         git
                         ccache
                         gcc-9
                         g++-9
                        )
        libra_pkgs_devel=(
            # For testing ARM cross-compilation
            gcc-9-arm-linux-gnueabihf
            g++-9-arm-linux-gnueabihf

            # For chrooting into an ARM image
            qemu
            qemu-user-static
            binfmt-support
            systemd-container

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
                         )
        rcppsw_pkgs_devel=(libboost-all-dev
                          liblog4cxx-dev
                         )

        cosm_pkgs_core=(ros-noetic-ros-base
                        ros-noetic-turtlebot3-bringup
                        ros-noetic-turtlebot3-msgs
                        qtbase5-dev
                        libfreeimageplus-dev
                        freeglut3-dev
                        libeigen3-dev
                        libudev-dev
                        liblua5.3-dev
                       )

        cosm_pkgs_devel=(
                         ros-noetic-desktop-full
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

        if [ "$build_env" = "DEVEL" ]; then
            # Install extra development packages (must be loop to ignore
            # ones that don't exist).
            for pkg in "${libra_pkgs_devel[@]} ${rcppsw_pkgs_devel[@]} ${cosm_pkgs_devel[@]}"
            do
                sudo apt-get -my install $pkg
            done
        fi
    fi



    if [ "$build_env" = "DEVEL" ]; then
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
}

function build_repos() {
    # Now that all system packages are installed, build all repos
    bootstrap_dir=$(pwd)
    mkdir -p $research_root && cd $research_root

    rcppsw_args=$([ "ROS" = "$platform" ] && echo "-DRCPPSW_AL_MT_SAFE_TYPES=NO" || echo "-DRCPPSW_AL_MT_SAFE_TYPES=YES")

    # Turtlebot actually has 4 cores, but not enough memory to be able
    # to do parallel compilation.
    n_cores=$([ "ETURTLEBOT3" = "$robot" ] && echo "-DN_CORES=1" || echo "")

    set -x
    cmake \
        -DRESEARCH_DEPS_PREFIX=$sys_install_prefix \
        -DRESEARCH_INSTALL_PREFIX=$research_install_prefix \
        -DRCSW_BRANCH=${configured_branches[rcsw]} \
        -DRCPPSW_BRANCH=${configured_branches[rcppsw]} \
        -DCOSM_BRANCH=${configured_branches[cosm]} \
        -DARGOS_BRANCH=${configured_branches[argos]} \
        -DFORDYCA_BRANCH=${configured_branches[fordyca]} \
        -DLIBRA_ER=$er_level \
        -DLIBRA_DEPS_PREFIX=$sys_install_prefix \
        -DCMAKE_BUILD_TYPE=$build_type \
        -DCOSM_BUILD_FOR=${platform}_${robot} \
        -DCOSM_BUILD_ENV=$build_env \
        $n_cores \
        $rcppsw_args \
        $bootstrap_dir

    # Use verbose make by default, to make debugging bad include paths,
    # etc. easier without having to re-run.
    make VERBOSE=1


    if [ "$platform" = "ROS" ]; then
        rm -rf $research_root/rosbridge
        mkdir -p $research_root/rosbridge && cd $research_root/rosbridge

        git clone -b ${configured_branches[sierra_rosbridge]} https://github.com/swarm-robotics/sierra_rosbridge.git src/sierra_rosbridge
        git clone -b ${configured_branches[fordyca_rosbridge]} https://github.com/swarm-robotics/fordyca_rosbridge.git src/fordyca_rosbridge

        # Turtlebot actually has 4 cores, but not enough memory to be able
        # to do parallel compilation.
        n_cores=$([ "ETURTLEBOT3" = "$robot" ] && echo "-j 1" || echo "")

        catkin init
        catkin config --extend /opt/ros/noetic --install --install-space=$research_install_prefix/ros
        catkin build $n_cores
    fi


    if [ "$build_env" = "DEVEL" ]; then
        cd $research_root

        # Clone SIERRA
        if [ -d sierra ]; then rm -rf sierra; fi
        git clone https://github.com/swarm-robotics/sierra.git
        cd sierra
        git checkout ${configured_branches[sierra]}
        pip3 install -r docs/requirements.txt
        cd docs && make man && cd ..
        pip3 install .
        cd ..

        # Clone TITERRA plugin
        if [ -d titerra ]; then rm -rf titerra; fi
        git clone https://github.com/swarm-robotics/titerra.git
        cd titerra
        git checkout ${configured_branches[titerra]}
        pip3 install -r docs/requirements.txt
        cd docs && make man && cd ..
        pip3 install .
        cd ..
    fi
}

function configure_build_env_post_build() {
    if [ "$build_env" = "MSI" ]; then
        if [ -L $SWARMROOT/bin/argos3-$MSIARCH ]; then
            rm -rf $SWARMROOT/bin/argos3-$MSIARCH
        fi
        ln -s  $SWARMROOT/$MSIARCH/bin/argos3 $SWARMROOT/bin/argos3-$MSIARCH
    fi
}

function configure_build_env_pre_build() {
    # Update turtlebot firmware; the version that comes on the latest version
    # silently doesn't work with the latest turtlebot3_msgs which comes from the
    # ubuntu repos.
    if [ "$build_env" = "ROBOT" ] && [ "$robot" = "ETURTLEBOT3" ]; then
        export OPENCR_PORT=/dev/ttyACM0
        export OPENCR_MODEL=burger_noetic
        wget https://github.com/ROBOTIS-GIT/OpenCR-Binaries/raw/master/turtlebot3/ROS1/latest/opencr_update.tar.bz2
        tar -xvf opencr_update.tar.bz2
        cd ./opencr_update
        ./update.sh $OPENCR_PORT $OPENCR_MODEL.opencr
        cd ..

        # Build will max out memory without this and get killed by the
        # OOM reaper.
        sudo apt-get install dphys-swapfile
    fi
}
function bootstrap_main() {
    # Install all packages
    install_packages

    export PATH=$PATH:$HOME/.local/bin

    # Exit when any command after this fails. Can't be before the package
    # installs, because it is not an error if some of the packages are not found
    # (I just put a list of possible packages that might exist on debian systems
    # to satisfy project requirements).
    set -e

    # Do pre-build per-build environment configuration.
    configure_build_env_pre_build

    # Build all configured repos
    build_repos

    # Do post-build per-build environment configuration.
    configure_build_env_post_build

    # Made it!
    echo -e "********************************************************************************"
    echo -e "BOOTSTRAP SUCCESS!"
    echo -e "********************************************************************************"
}

function bootstrap_prompt() {
    branches=$(for K in "${!configured_branches[@]}"; do echo -n "$K -> ${configured_branches[$K]},\n"; done)
    branches=$(tabs 43; echo -ne $branches | sed -e "s|^|\t|g")

    echo -e "********************************************************************************"
    echo -e "Bootstrap Configuration Summary:"
    echo -e "********************************************************************************"
    echo -e ""
    echo -e ""
    echo -e "Install .deb packages                    : $install_sys_pkgs"
    echo -e "Clone repos to                           : $research_root"
    echo -e "Checkout branches                        : SEE BELOW"
    echo -e "$branches"
    echo -e "Install compiled dependencies to         : $sys_install_prefix"
    echo -e "Install compiled research projects to    : $research_install_prefix"
    echo -e "Build environment setup                  : $build_env"
    echo -e "Platform                                 : $platform"
    echo -e "Robot                                    : $robot"
    echo -e "Build type                               : $build_type"
    echo -e "Event reporting level                    : $er_level"

    echo -e ""
    echo -e ""
    echo -e "********************************************************************************"

    if [ "$do_prompt" = "YES" ]; then
        while true; do
            echo "Please verify the above configuration."
            echo "WARNING: Anything in the installation directories may be overwritten!"
            read -p "Execute bootstrap (yes/no)? " yn

            case $yn in
                [Yy]* ) break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

bootstrap_prompt
bootstrap_main
