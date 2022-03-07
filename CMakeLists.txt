project(swarm-robotics)

cmake_minimum_required(VERSION 3.21 FATAL_ERROR)

include(ExternalProject)

include(ProcessorCount)

# Unless overriden, compile with all the cores available on the host machine.
if(NOT DEFINED N_CORES)
  ProcessorCount(N_CORES)
endif()
message(STATUS "Building with ${N_CORES} cores")

################################################################################
# Setup Prefixes
################################################################################
if (CMAKE_CROSS_COMPILING)
  if(NOT RESEARCH_INSTALL_PREFIX)
    set(RESEARCH_INSTALL_PREFIX $ENV{HOME}/.local/${CMAKE_SYSTEM_PROCESSOR})
  endif()
  if(NOT RESEARCH_DEPS_PREFIX)
    set(RESEARCH_DEPS_PREFIX $ENV{HOME}/.local/${CMAKE_SYSTEM_PROCESSOR}/system)
  endif()
else()
  if(NOT RESEARCH_INSTALL_PREFIX)
    set(RESEARCH_INSTALL_PREFIX $ENV{HOME}/.local)
    endif()
    if(NOT RESEARCH_DEPS_PREFIX)
      set(RESEARCH_DEPS_PREFIX $ENV{HOME}/.local/system)
    endif()
endif()


################################################################################
# RCSW
################################################################################
ExternalProject_Add(rcsw
  PREFIX .
  GIT_REPOSITORY https://github.com/swarm-robotics/rcsw.git
  GIT_TAG ${RCSW_BRANCH}
  CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX} -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
  UPDATE_COMMAND mkdir -p build
  BUILD_COMMAND make all -j ${N_CORES}
  SOURCE_DIR rcsw
  BINARY_DIR rcsw/build
  )

################################################################################
# RCPPSW
################################################################################

set(BOOST_REQUESTED_VERSION 1.71.0)

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

ExternalProject_Add(ticpp
  DEPENDS
  PREFIX .
  GIT_REPOSITORY https://github.com/wxFormBuilder/ticpp.git
  GIT_TAG master
  CMAKE_ARGS
  -DCMAKE_INSTALL_PREFIX=${RESEARCH_DEPS_PREFIX}
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
  UPDATE_COMMAND mkdir -p build
  CONFIGURE_COMMAND cmake
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DCMAKE_INSTALL_PREFIX=${RESEARCH_DEPS_PREFIX}
  ..
  PATCH_COMMAND git apply ${CMAKE_CURRENT_SOURCE_DIR}/ticpp.patch || true
  BUILD_COMMAND make all -j ${N_CORES} CFLAGS="-fPIC"
  SOURCE_DIR ticpp
  BINARY_DIR ticpp/build
  )

ExternalProject_Add(rcppsw
  DEPENDS rcsw ticpp
  PREFIX .
  GIT_REPOSITORY https://github.com/swarm-robotics/rcppsw.git
  GIT_TAG ${RCPPSW_BRANCH}
  CMAKE_ARGS
  -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX}
  -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
  -DLIBRA_ER=${LIBRA_ER}
  -DLIBRA_DEPS_PREFIX=${LIBRA_DEPS_PREFIX}
  -DRCPPSW_AL_MT_SAFE_TYPES=${RCPPSW_AL_MT_SAFE_TYPES}
  UPDATE_COMMAND git submodule update --init --remote --recursive && git pull --rebase && mkdir -p build
  BUILD_COMMAND make all -j ${N_CORES}
  SOURCE_DIR rcppsw
  BINARY_DIR rcppsw/build
  )

################################################################################
# ARGoS
################################################################################
if ("${COSM_BUILD_FOR}" MATCHES "ARGOS")
  # ARGoS
  ExternalProject_Add(argos
    PREFIX .
    GIT_REPOSITORY https://github.com/swarm-robotics/argos3.git
    GIT_TAG ${ARGOS_BRANCH}
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
      GIT_TAG ${EEPUCK3D_BRANCH}
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
endif()

################################################################################
# COSM
################################################################################
if ("${COSM_BUILD_FOR}" MATCHES "ARGOS")
  ExternalProject_Add(cosm
    DEPENDS argos rcppsw
    PREFIX .
    GIT_REPOSITORY https://github.com/swarm-robotics/cosm.git
    GIT_TAG ${COSM_BRANCH}
    UPDATE_COMMAND mkdir -p build
    BUILD_COMMAND make all -j ${N_CORES}
    CMAKE_ARGS
    -DCOSM_BUILD_FOR=${COSM_BUILD_FOR}
    -DCOSM_BUILD_ENV=${COSM_BUILD_ENV}
    -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DLIBRA_DEPS_PREFIX=${LIBRA_DEPS_PREFIX}
    SOURCE_DIR cosm
    BINARY_DIR cosm/build
    )
elseif ("${COSM_BUILD_FOR}" MATCHES "ROS")
  # COSM with ROS
  ExternalProject_Add(cosm
    DEPENDS rcppsw
    PREFIX .
    GIT_REPOSITORY https://github.com/swarm-robotics/cosm.git
    GIT_TAG ${COSM_BRANCH}
    UPDATE_COMMAND git submodule update --init --remote --recursive && git pull --rebase && mkdir -p build
    BUILD_COMMAND make all -j ${N_CORES}
    CMAKE_ARGS
    -DCOSM_BUILD_FOR=${COSM_BUILD_FOR}
    -DCOSM_BUILD_ENV=${COSM_BUILD_ENV}
    -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DLIBRA_DEPS_PREFIX=${LIBRA_DEPS_PREFIX}
    SOURCE_DIR cosm
    BINARY_DIR cosm/build
    )
endif()

################################################################################
# Fordyca
################################################################################
set(FORDYCA_DEPENDS cosm)

if("${COSM_BUILD_ENV}" MATCHES "MSI")
  ExternalProject_Add(nlopt
    PREFIX .
    GIT_REPOSITORY  https://github.com/stevengj/nlopt.git
    GIT_TAG master
    UPDATE_COMMAND mkdir -p build
    CONFIGURE_COMMAND cmake ..
    -DCMAKE_BUILD_TYPE=RelWithDebInfo
    -DCMAKE_INSTALL_PREFIX=${RESEARCH_DEPS_PREFIX}
    -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DNLOPT_PYTHON=NO
    -DNLOPT_OCTAVE=NO
    -DNLOPT_MATLAB=NO
    -DNLOPT_GUILE=NO
    -DNLOPT_SWIG=NO
    UPDATE_COMMAND mkdir -p build
    BUILD_COMMAND make -j ${N_CORES}
    SOURCE_DIR nlopt
    BINARY_DIR nlopt/build
    )
  set(FORDYCA_DEPENDS ${FORDYCA_DEPENDS} nlopt)
endif()

if("${COSM_BUILD_FOR}" MATCHES "ARGOS")
  # Fordyca with ARGoS
  ExternalProject_Add(fordyca
    DEPENDS ${FORDYCA_DEPENDS}
    PREFIX .
    GIT_REPOSITORY https://github.com/swarm-robotics/fordyca.git
    GIT_TAG ${FORDYCA_BRANCH}
    UPDATE_COMMAND mkdir -p build
    BUILD_COMMAND make all -j ${N_CORES}
    CMAKE_ARGS
    -DCOSM_BUILD_FOR=${COSM_BUILD_FOR}
    -DCOSM_BUILD_ENV=${COSM_BUILD_ENV}
    -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DLIBRA_DEPS_PREFIX=${LIBRA_DEPS_PREFIX}
    -DFORDYCA_WITH_ROBOT_LEDS=YES
    SOURCE_DIR fordyca
    BINARY_DIR fordyca/build
    )
elseif ("${COSM_BUILD_FOR}" MATCHES "ROS")
  # Fordyca with ROS
  ExternalProject_Add(fordyca
    DEPENDS ${FORDYCA_DEPENDS}
    PREFIX .
    GIT_REPOSITORY https://github.com/swarm-robotics/fordyca.git
    GIT_TAG ${FORDYCA_BRANCH}
    UPDATE_COMMAND git submodule update --init --remote --recursive && git pull --rebase && mkdir -p build
    BUILD_COMMAND make all -j ${N_CORES}
    CMAKE_ARGS
    -DCOSM_BUILD_FOR=${COSM_BUILD_FOR}
    -DCOSM_BUILD_ENV=${COSM_BUILD_ENV}
    -DCMAKE_INSTALL_PREFIX=${RESEARCH_INSTALL_PREFIX}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DLIBRA_DEPS_PREFIX=${LIBRA_DEPS_PREFIX}
    SOURCE_DIR fordyca
    BINARY_DIR fordyca/build
    )
endif()
