#!/bin/bash

source $(dirname $0)/util.sh
source $1

# uh... is this right?
export PATH=bin:argo_navis/bin:$PATH

if [ ${DEME_SPECIFICATION_SELECTOR} == "regexp" ]
then
  # If we have a regexp, will need to create the specification file to pass along
  metadata_from_seqnames.py -d "${DEME_SPECIFICATION_REGEX}" ${ALIGNMENT} tmp_deme_spec.csv
  DEME_SPECIFICATION_FILE=tmp_deme_spec.csv
fi

for deme in $( csvcut -c deme $DEME_SPECIFICATION_FILE | sed 1d | sort | uniq ); do
  # here we do the work for each deme and then combine
  mkdir -p $deme
  if [ ${SUBSAMPLING_METHOD} == "random" ] ; then
    # do stuff
  else
    # do other stuff
  fi
done


