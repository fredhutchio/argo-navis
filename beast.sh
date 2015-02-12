#!/bin/bash

source $(dirname $0)/util.sh
source $1


# COMPUTE METADATA IF NEEDED!
# ===========================

if [[ $METADATA_SPECIFICATION == "regex" ]]
then
  # First make sure we actually have an alignment to operate on
  if [[ ${ALIGNMENT} == "" ]]
  then
    echo "Must have alignment in order to specify metadata via regular expression" > /dev/stderr
    exit 1
  fi
  DEME_COLUMN="deme"
  # If we have a regex, will need to create the specification file to pass along
  if [[ $DATE_REGEX != "" ]]
  then
    DATE_REGEX_FLAG="-t $DATE_REGEX"
    # Need to let things know downstream that there is a date column in the constructed metadata
    DATE_COLUMN="date"
  else
    DATE_REGEX_FLAG=""
    DATE_COLUMN=""
  fi
  metadata_from_seqnames.py -d "$DEME_REGEX" ${DATE_REGEX_FLAG} \
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
  if [[ $DOWNSAMPLING_RANDOM_SEED == "" ]]
  then
    DOWNSAMPLING_RANDOM_SEED=$RANDOM
    echo "You did not specify a random seed for this run, so this one is being used, in case you'd like to
      reproduce your results: $DOWNSAMPLING_RANDOM_SEED"
  else
    DS_RANDOM_SEED_FLAG="-s $DOWNSAMPLING_RANDOM_SEED"
  fi
  # This script does the downsampling
  deme_downsample.py $DS_RANDOM_SEED_FLAG -m $DOWNSAMPLING_METHOD -k $DOWNSAMPLING_K -c $DEME_COLUMN \
    $ALIGNMENT $METADATA_FILE \
    $DOWNSAMPLED_ALIGNMENT downsampled_metadata.csv
  # Assign these to the unsampled variable names so the code below follows the same flow regardless
  ALIGNMENT=$DOWNSAMPLED_ALIGNMENT
  METADATA_FILE=downsampled_metadata.csv
  # If we are downsampling and specified a metadata file, make sure to return a downsampled_metadata file
  if [[ $METADATA_SPECIFICATION == "file" ]]
  then
    cp downsampled_metadata.csv $DOWNSAMPLED_METADATA
  fi
fi



# CONSTRUCT BEASTFILE AND RUN BEAST
# =================================

# Make a metadata flag we can pass into the format command
if [[ $METADATA_FILE != "" ]]
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
  # We assure this state location works by renaming the beastfile to beastfile.xml later
  cp $RESUME_STATEFILE beastfile.xml.state
else
  # Otherwise, set the full flag collection
  RESUME_FLAG=""
  FORMAT_ARGS="$ALIGNMENT_FLAG $META_FLAG $SAMPLES_FLAG $SAMPLING_INTERVAL_FLAG"
  # Add deme information only if we know what column it is (which will only be if we have metadata or regexs)
  if [[ $DATE_COLUMN != "" ]]
  then
    FORMAT_ARGS="$FORMAT_ARGS -d $DEME_COLUMN"
  fi
  # Add the date information only if a date column is specified
  if [[ $DATE_COLUMN != "" ]]
  then
    FORMAT_ARGS="$FORMAT_ARGS -D $DATE_COLUMN"
  fi
fi

# Format our beastfile
format_beastfile.py $BEASTFILE_TEMPLATE $FORMAT_ARGS $FORMATTED_BEASTFILE

# Actually run BEAST and set the output vars to their locations
cp $FORMATTED_BEASTFILE beastfile.xml
# The manual path is because matsengrp's beast is v1
/home/csmall/local/bin/beast $RANDOM_SEED_FLAG $RESUME_FLAG beastfile.xml

# Copy files over to the locations Galaxy has specified for them
cp posterior.log $LOGFILE
cp posterior.trait.trees $TREEFILE
cp beastfile.xml.state $STATEFILE


# LOGFILE TRIMMING FOR RESUME RUNS
# ================================

if [ $RESUME_SELECTOR == "true" ]
then
  posterior_subset.clj -t logfile -c $RESUME_SAMPLES $LOGFILE $TRIMMED_LOGFILE
  posterior_subset.clj -t treefile -c $RESUME_SAMPLES $TREEFILE $TRIMMED_TREEFILE
fi

