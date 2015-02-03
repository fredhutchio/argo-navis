#!/bin/bash

source $(dirname $0)/util.sh
source $1

# uh... is this right?
export PATH=bin:argo_navis/bin:$PATH

if [ ${DEME_SPECIFICATION_SELECTOR} == "regexp" ]
then
  # If we have a regexp, will need to create the specification file to pass along
  # XXX where should we keep temp stufs?
  metadata_from_seqnames.py -d "${DEME_SPECIFICATION_REGEX}" ${ALIGNMENT} tmp_deme_spec.csv
  DEME_SPECIFICATION_FILE=tmp_deme_spec.csv
fi

deme_downsample.py -m $SUBSAMPLING_METHOD -k $N_PER_DEME \
  $ALIGNMENT $DEME_SPECIFICATION_FILE \
  $SUBSAMPLED_ALIGNMENT $SUBSAMPLED_DEME_SPEC_FILE


