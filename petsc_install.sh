#!/usr/bin/bash

set -euo pipefail
IFS=$'\n\t'

mkdir -p tmp
export TMP="$(realpath tmp)"
export TEMP="$TMP"
export TMPDIR="$TMP"

INSTALL_ROOT="/discofs/$(whoami)"
INSTALL_OPT="${INSTALL_ROOT}/opt/software"

INSTALL_PETSC_COMPILER="intel"  # "intel" or "gcc"
INSTALL_PETSC_MPI="openmpi"
INSTALL_PETSC_HDF5_FORCE_MODULE=""
INSTALL_PETSC_HDF5_VERSION="1.13"
INSTALL_PETSC_OPT="opt"  # "opt" or "dbg" or "fast"
INSTALL_PETSC_VERSION_MAJOR="3"
INSTALL_PETSC_VERSION_MINOR="19.4"
INSTALL_PETSC_VERSION="${INSTALL_PETSC_VERSION_MAJOR}.${INSTALL_PETSC_VERSION_MINOR}"
INSTALL_PETSC_TAG="v${INSTALL_PETSC_VERSION}"

INSTALL_PETSC_HDF5_MODULENAME="${INSTALL_PETSC_HDF5_FORCE_MODULE:-hdf5/1/${INSTALL_PETSC_HDF5_VERSION}/latest-${INSTALL_PETSC_COMPILER}-${INSTALL_PETSC_MPI}}"
echo "Using $INSTALL_PETSC_HDF5_MODULENAME as base."

if [[ ${INSTALL_PETSC_COMPILER} =~ "intel" ]]; then
  
  mpiicc &>/dev/null && INSTALL_MPICC='mpiicc' || INSTALL_MPICC='mpicc'
  mpiicpc &>/dev/null && INSTALL_MPICXX='mpiicpc' || INSTALL_MPICXX='mpicxx'
  mpiifort &>/dev/null && INSTALL_MPIF90='mpiifort' || INSTALL_MPIF90='mpif90'
else
  INSTALL_MPICC='mpicc'
  INSTALL_MPICXX='mpicxx'
  INSTALL_MPIF90='mpif90'
fi

if [[ ${INSTALL_PETSC_MPI} =~ "mpich" ]]; then
  if [[ ${INSTALL_PETSC_COMPILER} =~ "intel" ]]; then
    export MPICH_CC="icc"
    export MPICH_CXX="icpc"
    export MPICH_FC="ifort"
  fi
fi

if [[ ${INSTALL_PETSC_OPT} == "fast" ]]; then
  INSTALL_CFLAGS='-Ofast -DNDEBUG'
  INSTALL_CXXFLAGS="${INSTALL_CFLAGS}"
  INSTALL_FFLAGS="${INSTALL_CFLAGS}"
  INSTALL_PETSC_WITH_DEBUGGING='no'
elif [[ ${INSTALL_PETSC_OPT} == "opt" ]]; then
  INSTALL_CFLAGS='-O3 -DNDEBUG'
  INSTALL_CXXFLAGS="${INSTALL_CFLAGS}"
  INSTALL_FFLAGS="${INSTALL_CFLAGS}"
  INSTALL_PETSC_WITH_DEBUGGING='no'
else
  INSTALL_PETSC_OPT='dbg'
  INSTALL_CFLAGS='-g -O0'
  INSTALL_CXXFLAGS="${INSTALL_CFLAGS}"
  INSTALL_FFLAGS="${INSTALL_CFLAGS}"
  INSTALL_PETSC_WITH_DEBUGGING='yes'
fi

if [[ ${INSTALL_PETSC_OPT} != "dbg" ]]; then
  if [[ ${INSTALL_PETSC_COMPILER} =~ "intel" ]]; then
    INSTALL_CFLAGS="${INSTALL_CFLAGS} -march=core-avx2 -mtune=core-avx2"
    INSTALL_CXXFLAGS="${INSTALL_CXXFLAGS} -march=core-avx2 -mtune=core-avx2"
    INSTALL_FFLAGS="${INSTALL_FFLAGS} -march=core-avx2 -mtune=core-avx2"
  elif [[ ${INSTALL_PETSC_COMPILER} =~ "aocc" ]]; then
    INSTALL_CFLAGS="${INSTALL_CFLAGS} -march=znver2"
    INSTALL_CXXFLAGS="${INSTALL_CXXFLAGS} -march=znver2"
    INSTALL_FFLAGS="${INSTALL_FFLAGS} -march=znver2"
  else
    INSTALL_CFLAGS="${INSTALL_CFLAGS} -march=znver2 -mtune=native"
    INSTALL_CXXFLAGS="${INSTALL_CXXFLAGS} -march=znver2 -mtune=native"
    INSTALL_FFLAGS="${INSTALL_FFLAGS} -march=znver2 -mtune=native"
  fi
fi

if [[ ${INSTALL_PETSC_COMPILER} =~ "intel" ]]; then
  INSTALL_CFLAGS="-diag-disable=10441 ${INSTALL_CFLAGS}"
  INSTALL_CXXFLAGS="-diag-disable=10441 ${INSTALL_CXXFLAGS}"
fi

module purge
module load $INSTALL_PETSC_HDF5_MODULENAME

IFS=$' \n\t'
echo "Calling the selected compilers"
echo "  ${INSTALL_MPICC} ${INSTALL_CFLAGS} --version"
${INSTALL_MPICC} ${INSTALL_CFLAGS} --version
echo
echo "  ${INSTALL_MPICXX} ${INSTALL_CXXFLAGS} --version"
${INSTALL_MPICXX} ${INSTALL_CXXFLAGS} --version
echo
echo "  ${INSTALL_MPIF90} ${INSTALL_FFLAGS} --version"
${INSTALL_MPIF90} ${INSTALL_FFLAGS} -diag-disable=10006 --version
echo
IFS=$'\n\t'

export PETSC_ARCH="${INSTALL_PETSC_COMPILER}-${INSTALL_PETSC_MPI}-${INSTALL_PETSC_OPT}"
PETSC_PREFIX="petsc/${INSTALL_PETSC_VERSION_MAJOR}/${INSTALL_PETSC_VERSION}/${PETSC_ARCH}"
INSTALL_PETSC_FULL_PREFIX="${INSTALL_OPT}/${PETSC_PREFIX}"
mkdir -p "$INSTALL_PETSC_FULL_PREFIX"

PETSC_CLONE_DIR="${TMPDIR}/petsc-${INSTALL_PETSC_TAG}"
rm -rf ${PETSC_CLONE_DIR}
git clone -b "${INSTALL_PETSC_TAG}" --depth=1 https://gitlab.com/petsc/petsc.git "${PETSC_CLONE_DIR}" || true
pushd "${PETSC_CLONE_DIR}"
./configure \
  --prefix="$INSTALL_PETSC_FULL_PREFIX" \
  --with-debugging=${INSTALL_PETSC_WITH_DEBUGGING} \
  --with-batch \
  --with-cc="${INSTALL_MPICC}" \
  --with-cxx="${INSTALL_MPICXX}" \
  --with-fc="${INSTALL_MPIF90}" \
  COPTFLAGS=${INSTALL_CFLAGS} \
  CXXOPTFLAGS=${INSTALL_CXXFLAGS} \
  FOPTFLAGS=${INSTALL_FFLAGS} \
  --download-sowing=yes \
  --download-fblaslapack=yes \
  --download-hypre=yes

make
make install
popd

MODULE_INSTALL_ROOT="${INSTALL_OPT}/modulefiles"
MODULEFILE_PATH="${MODULE_INSTALL_ROOT}/${PETSC_PREFIX}"
MODULEFILE_DIR="$(dirname ${MODULE_INSTALL_ROOT}/${PETSC_PREFIX})"
mkdir -p "$MODULEFILE_DIR"

cat > "$MODULEFILE_PATH" <<EOF
#%Module 1.0

module load $INSTALL_PETSC_HDF5_MODULENAME

set prefix $INSTALL_PETSC_FULL_PREFIX

prepend-path PATH            \$prefix/bin
prepend-path LD_LIBRARY_PATH \$prefix/lib
prepend-path LD_RUN_PATH     \$prefix/lib
prepend-path PKG_CONFIG_PATH \$prefix/lib/pkgconfig

prepend-path --delim " " CFLAGS   "-I\$prefix/include"
prepend-path --delim " " CXXFLAGS "-I\$prefix/include"
prepend-path --delim " " FCFLAGS  "-I\$prefix/include"
prepend-path --delim " " LDFLAGS  "-L\$prefix/lib"
EOF

echo "PETSc should have been installed."
echo "  Module files are provided with this installation."
echo "  Running the following commands should put PETSc in your PATH:"
echo
echo '    export MODULEPATH="'"${MODULE_INSTALL_ROOT}"'${MODULEPATH:+:$MODULEPATH}"'
echo '    module load petsc'
echo
echo '  The first line may be added to your ~/.bash_profile if it works.'
echo
