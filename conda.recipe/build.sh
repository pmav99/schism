#!/usr/bin/env bash

set -xeuo pipefail

#export mpi=mpich
export CC=mpicc
export CXX=mpicxx
export FC=mpif90
export F77=mpif77
export F90=mpif90

# build and install schism
mkdir build
cd build

cmake \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DCMAKE_BUILD_TYPE="Release" \
    -DCMAKE_Fortran_FLAGS_RELEASE_INIT="-O2 -ffree-line-length-none" \
    -DBLD_STANDALONE=$BLD_STANDALONE \
    -DTVD_LIM=$TVD_LIM \
    -DOLDIO=$OLDIO \
    -DPREC_EVAP=$PREC_EVAP \
    -DUSE_GOTM=$GOTM \
    -DUSE_HA=$HA \
    -DUSE_SED2D=$SED2D \
    -DUSE_MARSH=$MARSH \
    -DUSE_WWM=$WWM \
    -DUSE_WW3=$WW3 \
    -DUSE_ICE=$ICE \
    -DUSE_ICM=$ICM \
    -DUSE_GEN=$GEN \
    -DUSE_AGE=$AGE \
    -DUSE_ECO=$ECO \
    -DICM_PH=$PH \
    -DUSE_COSINE=$COSINE \
    -DUSE_FIB=$FIB \
    -DUSE_FABM=$FABM \
    -DUSE_SED=$SED \
    -DNO_PARMETIS=$NO_PARMETIS \
    ../src

make

##make install
cp -r bin/* $PREFIX/bin/
#make a symlink for convenience
executable=$(find $PREFIX/bin/ -type f -name 'pschism*' -exec test -x {} \; -print)
ln -s "${executable}" $PREFIX/bin/schism

#clean up
cd ..
rm -r build

cd $BUILD_PREFIX
