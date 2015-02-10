#!/bin/bash

source $(dirname $0)/util.sh
source $1


# COMPUTE METADATA IF NEEDED!
# ===========================

if [[ $METADATA_SPECIFICATION == "regexp" ]]
then
  # First make sure we actually have an alignment to operate on
  if [[ ${ALIGNMENT} == "" ]]
  then
    echo "Must have alignment in order to specify metadata via regular expression" > /dev/stderr
    exit 1
  fi
  # If we have a regexp, will need to create the specification file to pass along
  if [[ $DATE_REGEX != "" ]]
  then
    DATE_REGEX_FLAG="-D $DATE_REGEX"
    # Need to let things know downstream that there is a date column in the constructed metadata
    DATE_COLUMN="date"
  fi
  metadata_from_seqnames.py -d "$DEME_REGEX_FLAG" ${DATE_REGEX_FLAG} \
    ${ALIGNMENT} tmp_deme_spec.csv
  METADATA_FILE=tmp_deme_spec.csv
fi



# HANDLE DOWNSAMPLING
# ===================

if [[ $DOWNSAMPLING_METHOD != "none" ]]
then
  if [[ $METADATA_FILE == "" || $ALIGNMENT == "" ]]
  then
    echo "Must specify deme and alignment data in order to downsample" > /dev/stdout
    exit 1
  fi
  # This script does the downsampling
  deme_downsample.py -m $DOWNSAMPLING_METHOD -k $DOWNSAMPLING_K -c $DEME_COLUMN \
    $ALIGNMENT $METADATA_FILE \
    $DOWNSAMPLED_ALIGNMENT $DOWNSAMPLED_METADATA
  # Assign these to the unsampled variable names so the code below follows the same flow regardless
  ALIGNMENT=$DOWNSAMPLED_ALIGNMENT
  METADATA_FILE=$DOWNSAMPLED_METADATA
fi



# CONSTRUCT BEASTFILE AND RUN BEAST
# =================================

# Make a metadata flag we can pass into the format command
if [[ -n $METADATA_FILE ]]
then
  # Then use either the file given to us, or the one we constructed from regexprs
  META_FLAG="-m $METADATA_FILE"
else
  META_FLAG=""
fi

# Make a metadata flag we can pass into the format command
if [[ -n $ALIGNMENT ]]
then
  # Then use either the file given to us, or the one we constructed from regexprs
  ALIGNMENT_FLAG="-a $ALIGNMENT"
else
  ALIGNMENT_FLAG=""
fi

# Set the default BEASTfile
if [ $BEASTFILE_SPECIFICATION == "default" ]
then
  # ARGO_TOOL_DIR gets defined in utils; magick sauce...
  BEASTFILE_TEMPLATE=$ARGO_TOOL_DIR/default_beastfile_template.xml
fi

# Fork on a bunch of things based on whether this is a resume run or not
if [ $RESUME_SELECTOR == "true" ]
then
  # There should be a specified beastfile if we're resuming, otherwise raise
  if [ $BEASTFILE_SPECIFICATION == "default" ]
  then
    echo "Must specify the beastfile output by last run if doing a resume run" > /dev/stdout
    exit 1
  fi
  # Take care of getting things set up for proper formatting and resuming
  FORMAT_ARGS="$SAMPLES_FLAG" # We don't want to accept any beastfile modifications except samples
  RESUME_FLAG="-resume"
  cp $RESUME_LOGFILE posterior.log
  cp $RESUME_TREEFILE posterior.trait.trees
else
  # Otherwise, set the full flag collection
  RESUME_FLAG=""
  FORMAT_ARGS="$ALIGNMENT_FLAG $META_FLAG $SAMPLES_FLAG $SAMPLING_INTERVAL_FLAG -d $DEME_COLUMN"
  # Add the date information only if a date column is specified
  if [[ $DATE_COLUMN != "" ]]
  then
    FORMAT_ARGS="$FORMAT_ARGS -D $DATE_COLUMN"
  fi
fi

# Format our beastfile
format_beastfile.py $BEASTFILE_TEMPLATE $FORMAT_ARGS beastfile.xml

echo "This is the mark of the beast:"
which beast

# Actually run BEAST and set the output vars to their locations
/home/csmall/local/bin/beast $RESUME_FLAG beastfile.xml # The manual path is because matsengrp's beast is v1

# XXX make sure format actually ensures these file locations don't change
# Copy files over to the locations Galaxy has specified for them
cp posterior.log $LOGFILE
cp posterior.trait.trees $TREEFILE



# LOGFILE TRIMMING FOR RESUME RUNS
# ================================

if [ $RESUME_SELECTOR == "true" ]
then
  # XXX Haven't hooked these outputs up yet
  #posterior_subset.clj -t treefile -c $RESUME_SAMPLES $TREEFILE $SUBSET_TREEFILE
  #posterior_subset.clj -t logfile -c $RESUME_SAMPLES $LOGFILE $SUBSET_LOGFILE
  echo "Still in stub mode"
fi


