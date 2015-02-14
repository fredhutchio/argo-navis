#!/bin/bash

source $(dirname $0)/util.sh
source $1

# Need this for csvkit features mostly XXX
PATH="/home/csmall/pythedge-clstr/bin:$PATH"



# PRELIMINARY RUN OF PACT FOR TMRCA AND DEME MAP
# ==============================================

PRELIM_DIR=prelim_dir
mkdir $PRELIM_DIR


# First copy things over into our preliminary working dir
cp $ARGO_TOOL_DIR/prelim_pact_params $PRELIM_DIR/in.param
cp $TREEFILE $PRELIM_DIR/in.trees

# Go in and run; get out
cd $PRELIM_DIR
pact
cd ..

# Get id -> seqname translation from nexus treefile translations
ID_TRANSLATION=id_translation.csv
extract_nexus_translations.py $TREEFILE $ID_TRANSLATION

# Translate the tree rules so we have some metadata to work with
PRELIM_PARSED_PACT_TREE="prelim_parsed_pact_tree.csv"
ls $PRELIM_DIR
parse_pact_tree.py $PRELIM_DIR/out.rules $PRELIM_PARSED_PACT_TREE

# Join preliminary parsed pact tree data and id translation so we get metadata mapping seqname to deme
METADATA="metadata.csv"
csvjoin -c id,name $ID_TRANSLATION $PRELIM_PARSED_PACT_TREE | \
  csvcut -c id,sequence,label - | \
  sed '1 s/label/deme/' > $METADATA

# Extract average time to MRCA from the out.stats
TMRCA=`csvgrep -t -c statistic -m tmrca $PRELIM_DIR/out.stats | csvcut -c mean | grep -v mean`



# INITIALIZE THINGS
# =================

WORK_DIR=working_dir
mkdir $WORK_DIR

# We're using arrays here to solve this problem:
# http://stackoverflow.com/questions/12136948/in-bash-why-do-shell-commands-ignore-quotes-in-arguments-when-the-arguments-are
# Can't really seem to get multiple deme or tip names in otherwise
PACT_ARGS=($TREEFILE "-d" "deme" "-r" "-o" $WORK_DIR)



# SET UP TIP SELECTION
# ====================

if [[ $TIP_SELECTION_METHOD == "demes" ]]
then
  PACT_ARGS+=("-l" "\"$DEMES\"" "-m" $METADATA)
elif [[ $TIP_SELECTION_METHOD == "names" ]]
then
  PACT_ARGS+=("-t" $TIP_NAMES)
elif [[ $TIP_SELECTION_METHOD == "file" ]]
then
  PACT_ARGS+=("-T" $TIP_FILE)
fi


# TIME RANGE SELECTION
# ====================

if [[ $TIME_RANGE_SELECTOR != "custom" ]]
then
  PACT_ARGS+=("-s" $TMRCA)
  # Add custom logic for doing two prelim pact runs to get the tmrca for just focus tips
else
  # Still have to write the --strim-start for this into the wrapper
  PACT_ARGS+=("-e" $TIME_RANGE_END)
  if [[ $TIME_RANGE_START != "" ]]
  then
    PACT_ARGS+=("-S" $TIME_RANGE_START)
  fi
fi


# RUN IT
# ======

# Again, as mentioned above, have to do this array thing to get arg list construction to work properly
pact_wrapper.py "${PACT_ARGS[@]}"
# XXX Stubbing code! Comment out the above, and in the below; or vice versa
#echo "Would be calling PACT with args: $PACT_ARGS"
#WORK_DIR=/home/matsengrp/working/csmall/galaxy-central/database/job_working_directory/000/62/working_dir


OUT_RULES="$WORK_DIR/out.rules"
OUT_STATS="$WORK_DIR/out.stats"
OUT_SKYLINES="$WORK_DIR/out.skylines"



# PLOTTING RESULTS
# ================

# Thread access to some shared plotting code
COMMONR="$ARGO_TOOL_DIR/bin/common.R"

# First we're going to create a file with the deme list, for more predicatable coloring:
FULL_DEME_LIST="full_deme_list"
csvcut -t -c statistic $OUT_STATS | \
  csvgrep -c statistic -r "^pro_" | \
  sed s/pro_// | \
  sed '1 s/statistic/deme/' > $FULL_DEME_LIST

# Specify colors
COMMON_ARGS="$COMMONR -d $FULL_DEME_LIST"
if [[ $COLOR_SELECTOR == "brewer" ]]
then
  COMMON_ARGS="$COMMON_ARGS -b $COLOR_BREWER"
else
  COMMON_ARGS="$COMMON_ARGS -c $COLOR_FILE"
fi

# Parse the out.rules file and make a tree plots of it
TREE_PLOT="tree_plot.svg"
parse_pact_tree.py $OUT_RULES parsed_pact_tree.csv
csvjoin --left -c name,id parsed_pact_tree.csv $ID_TRANSLATION > parsed_pact_tree.renamed.csv

plot_pact_tree.R $COMMON_ARGS parsed_pact_tree.renamed.csv $TREE_PLOT

# Make skyline plot
SKYLINE_PLOT="skyline_plot.svg"
plot_skyline_hist.R $COMMON_ARGS $OUT_SKYLINES $OUT_STATS $SKYLINE_PLOT

# Do migration rate plot
MIGRATION_RATES_PLOT="migration_rates_plot.svg"
plot_migration_rates.R $COMMON_ARGS $OUT_STATS $MIGRATION_RATES_PLOT

# Other stats extraction
MISC_STATS="misc_stats.svg"
grep -v mig $OUT_STATS | column -t | txt2svg -s 3.5 - $MISC_STATS

# Title SVG
TITLE="title.svg"
echo $FIGURES_TITLE | txt2svg -s 8 - $TITLE

# Start combining results using svgstack, and convert the final result to PDF w/ inkscape
STATS="stats.svg"
MAIN="main.svg"
COMBINED_SVG="combined.svg"
svg_stack.py --direction="v" $MIGRATION_RATES_PLOT $MISC_STATS > $STATS
svg_stack.py --direction="h" $TREE_PLOT $SKYLINE_PLOT $STATS > $MAIN
svg_stack.py --direction="v" $TITLE $MAIN > $COMBINED_SVG
inkscape --without-gui --export-pdf=$FIGURES $COMBINED_SVG


