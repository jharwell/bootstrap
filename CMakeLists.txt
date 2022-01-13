project(swarm-robotics)

cmake_minimum_required(VERSION 3.22 FATAL_ERROR)

include(ExternalProject)

include(ProcessorCount)
ProcessorCount(N_CORES)
# set(N_CORES 1)

if (CMAKE_CROSS_COMPILING)
  if(NOT RESEARCH_INSTALL_PREFIX)
    set(RESEARCH_INSTALL_PREFIX /home/$ENV{USER}/.local/${CMAKE_SYSTEM_PROCESSOR})
  endif()
  if(NOT RESEARCH_DEFS_PREFIX)
    set(RESEARCH_DEPS_PREFIX /home/$ENV{USER}/.local/${CMAKE_SYSTEM_PROCESSOR}/system)
  endif()
else()
  if(NOT RESEARCH_INSTALL_PREFIX)
    set(RESEARCH_INSTALL_PREFIX /home/$ENV{USER}/.local)
    endif()
    if(NOT RESEARCH_DEFS_PREFIX)
      set(RESEARCH_DEPS_PREFIX /home/$ENV{USER}/.local/system)
    endif()
endif()


# RCSW
ExternalProject_Add(rcsw
  PREFIX .
  GIT_REPOSITORY https://github.com/swarm-robotics/rcsw.git
  GIT_TAG devel
  CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX}
  UPDATE_COMMAND mkdir -p build
  BUILD_COMMAND make all -j ${N_CORES}
  SOURCE_DIR rcsw
  BINARY_DIR rcsw/build
  )

set(BOOST_REQUESTED_VERSION 1.71.0)

# RCPPSW
if(CMAKE_CROSSCOMPILING)
  set(BOOST_ROOT ${RESEARCH_DEPS_PREFIX})
  string(REPLACE "." "_" BOOST_REQUESTED_VERSION_TAR "${BOOST_REQUESTED_VERSION}")

  ExternalProject_Add(
    Boost
    URL https://boostorg.jfrog.io/artifactory/main/release/${BOOST_REQUESTED_VERSION}/source/boost_${BOOST_REQUESTED_VERSION_TAR}.tar.gz
    UPDATE_COMMAND ./bootstrap.sh
    PATCH_COMMAND patch -p0 < ${CMAKE_CURRENT_SOURCE_DIR}/boost.patch
    CONFIGURE_COMMAND ""
    BUILD_COMMAND ./b2 link=static --prefix=${BOOST_ROOT} install
    BUILD_IN_SOURCE true
    INSTALL_DIR ${BOOST_ROOT}
    )
  find_package(Boost ${BOOST_REQUESTED_VERSION}
    COMPONENTS
    ${BOOST_COMPONENTS}
    QUIET) # Must be quiet to not throw an error the first time through
else()
  find_package(Boost ${BOOST_REQUESTED_VERSION}
    COMPONENTS
    ${BOOST_COMPONENTS}
    REQUIRED)

endif()


ExternalProject_Add(rcppsw
  DEPENDS rcsw
  PREFIX .
  GIT_REPOSITORY https://github.com/swarm-robotics/rcppsw.git
  GIT_TAG devel
  CMAKE_ARGS
  -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX}
  -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
  -DLIBRA_ER=${LIBRA_ER}

  UPDATE_COMMAND mkdir -p build
  BUILD_COMMAND make all -j ${N_CORES}
  SOURCE_DIR rcppsw
  BINARY_DIR rcppsw/build
  )


if ("${PLATFORM}" MATCHES "ARGOS")
  # ARGoS
  ExternalProject_Add(argos
    PREFIX .
    GIT_REPOSITORY https://github.com/swarm-robotics/argos3.git
    GIT_TAG devel
    UPDATE_COMMAND mkdir -p build
    CONFIGURE_COMMAND cmake
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
    -DCMAKE_INSTALL_PREFIX=${RESEARCH_DEPS_PREFIX}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DARGOS_BUILD_FOR=simulator
    -DARGOS_BUILD_NATIVE=ON
    -DARGOS_THREADSAFE_LOG=ON
    -DARGOS_DYNAMIC_LIBRARY_LOADING=ON
    -DARGOS_DOCUMENTATION=OFF
    -DARGOS_USE_DOUBLE=ON
    -DARGOS_WITH_LUA=OFF
    -DARGOS_INSTALL_LDSOCONF=NO
    ../src
    BUILD_COMMAND make all -j ${N_CORES}
    SOURCE_DIR argos
    BINARY_DIR argos/build
    )
  if(BUILD_ARGOS_EEPUCK)
    ExternalProject_Add(argos-eepuck3D
      PREFIX .
      GIT_REPOSITORY https://github.com/swarm-robotics/argos3-eepuck3D.git
      GIT_TAG devel
      UPDATE_COMMAND mkdir -p build
      # This code expects ARGoS to be installed system wide, so we have to
      # tell it that where the necessary ARGoS cmake, pkgconfig, files are.
      CONFIGURE_COMMAND cmake
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_INSTALL_PREFIX=${RESEARCH_DEPS_PREFIX}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_LIBRARY_PATH=${RESEARCH_DEPS_PREFIX}/lib
      -DCMAKE_PREFIX_PATH=${RESEARCH_DEPS_PREFIX}/include
      -DCMAKE_MODULE_PATH=${RESEARCH_DEPS_PREFIX}/share
      ../src
      SOURCE_DIR argos-eepuck3D
      BINARY_DIR argos-eepuck3D/build

      )
  endif()

  # COSM with ARGoS
  ExternalProject_Add(cosm
    DEPENDS argos rcppsw
    PREFIX .
    GIT_REPOSITORY https://github.com/swarm-robotics/cosm.git
    GIT_TAG feature/164/base-ros-controller
    UPDATE_COMMAND mkdir -p build
    BUILD_COMMAND make all -j ${N_CORES}
    CMAKE_ARGS
    -DCOSM_BUILD_FOR=ARGOS_FOOTBOT
    -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DLIBRA_ER=${LIBRA_ER}
    SOURCE_DIR cosm
    BINARY_DIR cosm/build
    )

  # Fordyca with ARGoS
  ExternalProject_Add(fordyca
    DEPENDS cosm
    PREFIX .
    GIT_REPOSITORY https://github.com/swarm-robotics/fordyca.git
    GIT_TAG refactor/721/COSM-164-flowdown
    UPDATE_COMMAND mkdir -p build
    BUILD_COMMAND make all -j ${N_CORES}
    INSTALL_COMMAND ""
    CMAKE_ARGS
    -DCOSM_BUILD_FOR=ARGOS_FOOTBOT
    -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DLIBRA_ER=${LIBRA_ER}
    SOURCE_DIR fordyca
    BINARY_DIR fordyca/build
    )
elseif ("${PLATFORM}" MATCHES "ROS")
  # COSM with ROS
  ExternalProject_Add(cosm
    DEPENDS rcppsw
    PREFIX .
    GIT_REPOSITORY https://github.com/swarm-robotics/cosm.git
    GIT_TAG feature/164/base-ros-controller
    UPDATE_COMMAND mkdir -p build
    BUILD_COMMAND make all -j ${N_CORES}
    CMAKE_ARGS
    -DCOSM_BUILD_FOR=ROS_TURTLEBOT3
    -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DLIBRA_ER=${LIBRA_ER}
    SOURCE_DIR cosm
    BINARY_DIR cosm/build
    )

  # Fordyca with ROS
  ExternalProject_Add(fordyca
    DEPENDS cosm
    PREFIX .
    GIT_REPOSITORY https://github.com/swarm-robotics/fordyca.git
    GIT_TAG refactor/721/COSM-164-flowdown
    UPDATE_COMMAND mkdir -p build
    BUILD_COMMAND make all -j ${N_CORES}
    INSTALL_COMMAND ""
    CMAKE_ARGS
    -DCOSM_BUILD_FOR=ROS_TURTLEBOT3
    -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DLIBRA_ER=${LIBRA_ER}
    SOURCE_DIR fordyca
    BINARY_DIR fordyca/build
    )
endif()
