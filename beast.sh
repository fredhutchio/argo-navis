#!/bin/bash

source $(dirname $0)/util.sh
source $1

# XXX uh... is this right?
export PATH=bin:argo_navis/bin:$PATH


# Compute metadata if needed; otherwise leave alone
if [ ${META_SPECIFICATION_SELECTOR} == "regexp" ]
then
  # If we have a regexp, will need to create the specification file to pass along
  metadata_from_seqnames.py ${DEME_REGEX_FLAG} ${DATE_REGEX_FLAG} \
    ${ALIGNMENT} tmp_deme_spec.csv # XXX where should tmp live
  META_SPECIFICATION_FILE=tmp_deme_spec.csv
fi

# Make a metadata flag we can pass into the format command
if [ ${META_SPECIFICATION_FILE} == "" ]
then
  # Assume that the metadata is already in the beastfile (XXX deal with errors if no specified beastfile)
  META_FLAG=""
else
  # Then use either the file given to us, or the one we constructed from regexprs
  # XXX How do we deal with making sure the regexp metadata parses correctly? Offer optional files out for debug?
  META_FLAG="-m $META_SPECIFICATION_FILE"
fi

# Set the default BEASTfile
# XXX Will this actually work for "data" files?
if [ ! ${BEASTFILE} == "" ]
then
  # XXX Where will this get called? Where is the best place to put this as updatable resource?
  BEASTFILE=`readlink -f default_beastfile_template.xml`
fi

# Format our beastfile
format_beastfile.py $BEASTFILE $ALIGNMENT_FLAG $META_FLAG $SAMPLES_FLAG $SAMPLING_INTERVAL_FLAG beastfile.xml

# XXX Not sure yet how we actually deal with the resume data...
if [ ${RESUME_LOGFILE} ]
then
  RESUME_FLAG="-resume"
else
  RESUME_FLAG=""
fi

# XXX Also have to make sure here somewhere that we pass through the output file flags
# How does galaxy actually handle that?
beast "" beastfile.xml


