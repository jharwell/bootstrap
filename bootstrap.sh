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

--arch [x86_64,arm]: The architecture to build for. Default=x86_64.

-f|--force: Don't prompt before executing the bootstrap.

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
arch="x86_64"
do_prompt="YES"
build_type="DEV"
options=$(getopt -o hf --long help,opt,nosyspkgs,force,sysprefix:,rprefix:,rroot:,platform:,arch:  -n "BOOTSTRAP" -- "$@")
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
        --arch) arch=$2; shift;;
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
        libra_pkgs=(make
                    cmake
                    git
                    nodejs
                    npm
                    graphviz
                    ccache
                    doxygen
                    cppcheck
                    gcc-9
                    g++-9
                    gcc-9-arm-linux-gnueabihf
                    g++-9-arm-linux-gnueabihf
                    libclang-10-dev
                    clang-tools-10
                    clang-format-10
                    clang-tidy-10
                   )

        rcppsw_pkgs=(libboost-all-dev
                     liblog4cxx-dev
                     catch
                     ccache
                     python3-pip
                    )

        cosm_pkgs=(qtbase5-dev
                   libfreeimageplus-dev
                   freeglut3-dev
                   libeigen3-dev
                   libudev-dev
                   ros-noetic-desktop-full # Not present on rasberry pi
                   ros-noetic-ros-base
                   liblua5.3-dev
                  )

        # Modern cmake required, default with most ubuntu versions is too
        # old--use kitware PPA.
        wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | sudo tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null
        echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ focal main' | sudo tee /etc/apt/sources.list.d/kitware.list >/dev/null
        sudo apt-get update

        # Install packages (must be loop to ignore ones that don't exist)
        for pkg in "${libra_pkgs[@]} ${rcppsw_pkgs[@]} ${cosm_pkgs[@]}"
        do
            sudo apt-get -my install $pkg
        done
    fi

    python_pkgs=(
        # RCPPSW packages
        cpplint
        breathe
        exhale
    )
    pip3 install --user  "${python_pkgs[@]}"

    # Exit when any command after this fails. Can't be before the package
    # installs, because it is not an error if some of the packages are not found
    # (I just put a list of possible packages that might exist on debian systems
    # to satisfy project requirements).
    set -e

    # Now that all system packages are installed, build all repos
    bootstrap_dir=$(pwd)
    mkdir -p $research_root && cd $research_root

    # LIBRA
    # git clone https://github.com/swarm-robotics/libra.git

    er=$([ "OPT" = "$build_type" ] && echo "NONE" || echo "ALL")

    arch=$([ "arm" = "$arch" ] && echo "-DCMAKE_TOOLCHAIN_FILE=$research_root/libra/cmake/arm-linux-gnueabihf-toolchain.cmake" || echo "")

    cmake \
        -DPLATFORM=$platform \
        -DRESEARCH_DEPS_PREFIX=$sys_install_prefix \
        -DRESEARCH_INSTALL_PREFIX=$research_install_prefix \
        -DLIBRA_ER=$er \
        -DCMAKE_BUILD_TYPE=$build_type \
        $arch \
        $bootstrap_dir

    make

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
    echo -e "Architecture                             : $arch"
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
