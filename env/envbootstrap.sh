#!/bin/bash
# Usage: envbootstrap.sh [Options]

# Create a virtualenv, and install requirements to it.

# Requirements: wget, tar, git


#set -e


# Vars/options
SCRIPT_LOCATION=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)
VENV_VERSION=1.11.6

# options configurable from the command line
VENV=$(basename $(cd $SCRIPT_LOCATION/.. && pwd))-env
PYTHON=$(which python)
PY_VERSION=$($PYTHON -c 'import sys; print "{}.{}.{}".format(*sys.version_info[:3])')
REQFILE=$SCRIPT_LOCATION/requirements.txt

if [[ $1 == '-h' || $1 == '--help' ]]; then
    echo "Create a virtualenv and install all pipeline dependencies"
    echo "Options:"
    echo "--venv            - path of virtualenv [$VENV]"
    echo "--python          - path to an alternative python interpreter [$PYTHON]"
    echo "--requirements    - an alternative requiremets file [$REQFILE]"
    exit 0
fi

while true; do
    case "$1" in
  --venv ) VENV="$2"; shift 2 ;;
  --python ) PYTHON="$2"; shift 2 ;;
  --requirements ) REQFILE="$2"; shift 2 ;;
  * ) break ;;
    esac
done

mkdir -p src

# Create the virtualenv using a specified version of the virtualenv
# source. This also provides setuptools and pip. Inspired by
# http://eli.thegreenplace.net/2013/04/20/bootstrapping-virtualenv/

# create virtualenv if necessary
if [ ! -f ${VENV:?}/bin/activate ]; then
    # download virtualenv source if necessary
    if [ ! -f src/virtualenv-${VENV_VERSION}/virtualenv.py ]; then
       VENV_URL='https://pypi.python.org/packages/source/v/virtualenv'
       (cd src && \
          wget -N ${VENV_URL}/virtualenv-${VENV_VERSION}.tar.gz && \
          tar -xf virtualenv-${VENV_VERSION}.tar.gz)
    fi
    $PYTHON src/virtualenv-${VENV_VERSION}/virtualenv.py $VENV
    $PYTHON src/virtualenv-${VENV_VERSION}/virtualenv.py --relocatable $VENV
else
    echo "found existing virtualenv $VENV"
fi

# Activate our new (or existing) virtual env
source $VENV/bin/activate
# contains the absolute path
VENV=$VIRTUAL_ENV

venv_abspath=$(readlink -f $VENV)

# First install all python requirements
pip install numpy
pip install scipy
pip install biopython
pip install lxml
pip install -r requirements.txt

# Next install R requirements, and set up R_LIBS export in env
R_LIBS=$VENV/lib/R
mkdir -p $R_LIBS
R_LIBS=$R_LIBS ./rdeps.R
echo "export R_LIBS=$R_LIBS" >> $VENV/env.sh


# For everything else, we'll try to use encapish setup
ENCAP=$VENV/encap
mkdir -p $ENCAP


# Next install BEAST
if [[ ! -f $VENV/bin/beast ]]; then
  (cd $ENCAP && \
    rm -rf BEAST.v2.1.3.tgz BEAST && \
    wget -N https://github.com/CompEvol/beast2/releases/download/v2.1.3/BEAST.v2.1.3.tgz && \
    tar -zxf BEAST.v2.1.3.tgz && \
    (ln -s ../encap/BEAST/bin/* ../bin/ & \
      ln -s ../encap/BEAST/lib/* ../lib))
fi

# Add the BEAST_CLASSIC package
addonmanager -add BEASTlabs
addonmanager -add BEAST_CLASSIC


# Next install PACT
if [[ ! -f $VENV/bin/pact ]]; then
  (cd $ENCAP && \
    rm -rf PACT && \
    git clone https://github.com/trvrb/PACT.git && \
    cd PACT && \
    make && \
    cd .. && \
    ln -s ../encap/PACT/pact ../bin/pact
    )
fi

# correct any more shebang lines
virtualenv --relocatable $VENV

