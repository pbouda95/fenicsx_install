#/usr/bin/bash
source ./sh/macros
# cea modules to load:
#module load python/3.8.6 gcc/11.2.0 openmpi/gcc_11.2.0 

# flag to be activated if the installation is done from scratch. In case of a relaunch, disable it
# in order to not clean enerything
WITH_CLEANING=false

WITH_PETSC=false
WITH_HDF5=false
WITH_UFL_BASIX_FFCX=false
WITH_DOLFINX=false
WITH_MFRONT=true

#######################################################################

# Variables initializaion
ROOT_DIR=`pwd`
#ROOT_DIR=/volatile/catB/pbdynphd/lm271806
NPROCS=`nproc --all`
INSTALL_DIR=$ROOT_DIR/fenicsx
PYTHON_ENV=$ROOT_DIR/env
RC_FPATH=$ROOT_DIR/.fenicsxrc

# #######################################################################
if $WITH_CLEANING
then
    rm -rf $PYTHON_ENV
    python -m venv $PYTHON_ENV
fi
# #######################################################################
if $WITH_CLEANING
then
    # fenicsxrc initialization
    rm $RC_FPATH
    fappend $RC_FPATH "#/usr/bin/bash\n#a config file to source files for fenics\n"
    # root clean
    cd $ROOT_DIR
    rm -rf $INSTALL_DIR
    mkdir -p $INSTALL_DIR
fi
#activate python env + requirements
fappend $RC_FPATH "\nsource $PYTHON_ENV/bin/activate"
source $RC_FPATH
python -m pip install --upgrade pip
pip install Cython==0.29.36 pkgconfig wheel numpy mpi4py pandas scipy meshio matplotlib

#######################################################################
# PETSC
#######################################################################

PETSC_INSTALL_DIR=$INSTALL_DIR/petsc
PETSC_VERSION=3.19.3
PETSC_NAME=petsc-$PETSC_VERSION
PETSC_ARCHIVE=$PETSC_NAME.tar.gz

fappend $RC_FPATH "#add petsc libs\nexport PYTHONPATH=$PETSC_INSTALL_DIR/$PETSC_NAME/arch-linux-c-debug/lib:\$PYTHONPATH"

if $WITH_PETSC
then
    rm -rf $PETSC_INSTALL_DIR
    mkdir -p $PETSC_INSTALL_DIR
    cd $PETSC_INSTALL_DIR
    wget https://www.mcs.anl.gov/petsc/mirror/release-snapshots/$PETSC_ARCHIVE
    tar xf $PETSC_ARCHIVE

    cd $PETSC_INSTALL_DIR/$PETSC_NAME
    ./configure --with-petsc4py=1
    make PETSC_DIR=$PETSC_INSTALL_DIR/$PETSC_NAME PETSC_ARCH=arch-linux-c-debug all
fi

#######################################################################
# HDF5
#######################################################################

#nb: mpi.h path might be necessary: export CPATH=/usr/lib/x86_64-linux-gnu/openmpi/include/:$CPATH

HDF5_INSTALL_DIR=$INSTALL_DIR/hdf5
HDF5_NAME=hdf5
H5PY_NAME=h5py
HDF5_TITANIA=/usr/lib/x86_64-linux-gnu/

if $WITH_HDF5
then
    rm -rf $HDF5_INSTALL_DIR
    mkdir -p $HDF5_INSTALL_DIR

    cd $HDF5_INSTALL_DIR
    rm -rf $HDF5_NAME
    git clone https://github.com/HDFGroup/$HDF5_NAME.git
    cd $HDF5_NAME
    git checkout hdf5-1_14_0
    HDF5_MPICC_BIN=`which mpicc`
    CC=$HDF5_MPICC_BIN ./configure --enable-shared --enable-parallel --prefix=$HDF5_INSTALL_DIR
    make -j $NPROCS
    make install

    cd $HDF5_INSTALL_DIR
    rm -rf $H5PY_NAME
    git clone https://github.com/h5py/$H5PY_NAME.git
    cd $H5PY_NAME
    git checkout 3.9.0
    export HDF5_DIR=$HDF5_INSTALL_DIR
    export HDF5_MPI=ON
    pip install --no-binary=h5py --no-deps .      
fi

#######################################################################
# UFL + BASIX + FFCX
#######################################################################

if $WITH_UFL_BASIX_FFCX
then
    pip uninstall fenics-ufl fenics-basix fenics-ffcx
    cd $INSTALL_DIR
    pip_install ufl 2023.1.1.post0
    cd $INSTALL_DIR
    pip_install basix v0.6.0
    cd $INSTALL_DIR
    pip_install ffcx v0.6.0
fi


#######################################################################
# DOLFINX
#######################################################################

DOLFINX_INSTALL_DIR=$INSTALL_DIR/dolfinx
DOLFINX_NAME=dolfinx

if $WITH_DOLFINX
then
    export PETSC_DIR=$PETSC_INSTALL_DIR/$PETSC_NAME/arch-linux-c-debug
    export HDF5_ROOT=$HDF5_INSTALL_DIR
#    export HDF5_ROOT=$HDF5_TITANIA

#    rm -rf $DOLFINX_INSTALL_DIR
#    mkdir -p $DOLFINX_INSTALL_DIR
#    cd $DOLFINX_INSTALL_DIR
#    rm -rf $DOLFINX_NAME
#    git clone https://github.com/FEniCS/$DOLFINX_NAME.git
    cd $DOLFINX_NAME
    git checkout v0.6.0
    cd $DOLFINX_INSTALL_DIR/$DOLFINX_NAME/cpp
    rm -rf build
    mkdir build
    cd build
    cmake -DCMAKE_INSTALL_PREFIX=$DOLFINX_INSTALL_DIR ..
    make install -j $NPROCS
    source $DOLFINX_INSTALL_DIR/lib/dolfinx/dolfinx.conf
    cd $DOLFINX_INSTALL_DIR/$DOLFINX_NAME/python
    pip install .
fi

#######################################################################
# MFRONT (tfel+mgis)
#######################################################################

MFRONT_INSTALL_DIR=$INSTALL_DIR/mfront
TFEL_INSTALL_DIR=$MFRONT_INSTALL_DIR/tfel
MGIS_INSTALL_DIR=$MFRONT_INSTALL_DIR/mgis

fappend $RC_FPATH "#add tfel executables\nexport PATH=$TFEL_INSTALL_DIR/bin:\$PATH"
fappend $RC_FPATH "#add tfel libs\nexport LD_LIBRARY_PATH=$TFEL_INSTALL_DIR/lib:\$LD_LIBRARY_PATH"
fappend $RC_FPATH "#add mgis libs\nexport LD_LIBRARY_PATH=$MGIS_INSTALL_DIR/lib:\$LD_LIBRARY_PATH"
fappend $RC_FPATH "#add mgis module\nPYTHON_VERSION=\"\$(python3 -c 'import sys; print(\".\".join(map(str, sys.version_info[0:2])))')\""
fappend $RC_FPATH "export PYTHONPATH=$MGIS_INSTALL_DIR/lib/python\$PYTHON_VERSION/site-packages/:\$PYTHONPATH"

if $WITH_MFRONT
then
    rm -rf $MFRONT_INSTALL_DIR
    mkdir -p $MFRONT_INSTALL_DIR $TFEL_INSTALL_DIR $MGIS_INSTALL_DIR

    cd $TFEL_INSTALL_DIR
    git clone https://github.com/thelfer/tfel.git
    cd tfel
    cmake -DCMAKE_BUILD_TYPE=Release -Denable-python=ON -DCMAKE_INSTALL_PREFIX=../ ./
    make install -j $NPROCS

    cd $MGIS_INSTALL_DIR
    git clone https://github.com/thelfer/MFrontGenericInterfaceSupport.git
    cd MFrontGenericInterfaceSupport
    cmake -DCMAKE_BUILD_TYPE=Release -Denable-website=OFF -Denable-python-bindings=ON -DCMAKE_INSTALL_PREFIX=../ ./
    make install -j $NPROCS

fi

deactivate
