#!/bin/bash

source $(dirname $0)/util.sh
source $1

# XXX uh... is this right?
export PATH=bin:argo_navis/bin:$PATH

# XXX - still need to test and wrap in a jar
posterior_subset.clj -t treefile $SAMPLES_FLAG $TREEFILE $SUBSET_TREEFILE
posterior_subset.clj -t logfile $SAMPLES_FLAG $LOGFILE $SUBSET_LOGFILE

