# .bashrc

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi
export PATH

export TZ='Europe/Zurich'

export SCRATCH="/discofs/$(whoami)"
export PROJECT="/discofs/$(whoami)"

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions

function gbsmoduleload(){
    PETSC_VERSION="${1:-3.19.4}"
    PETSC_COMPILER="${2:-intel}"
    PETSC_OPTLEVEL="${3:-opt}"
    PETSC_MPI='openmpi'
    PETSC_MAJOR_VERSION="$(echo $PETSC_VERSION | cut -d. -f1)"
    PETSC_MODULENAME="petsc/${PETSC_MAJOR_VERSION}/${PETSC_VERSION}/${PETSC_COMPILER}-${PETSC_MPI}-${PETSC_OPTLEVEL}"
    module load "$PETSC_MODULENAME"
    export CC=mpicc CXX=mpicxx FC=mpifort
}
