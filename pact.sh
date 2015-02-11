#!/bin/bash

source $(dirname $0)/util.sh
source $1



# INITIALIZE THINGS
# =================

WORK_DIR=working_dir
mkdir $WORK_DIR

PACT_ARGS="$TREEFILE -r -o $WORK_DIR"



# SET UP TIP SELECTION
# ====================

if [[ $TIP_SELECTION_METHOD == "deme" ]]
then
  # XXX We need meadata or regexp for this one; not sure if there's a way around it
  echo "XXX Still in stub"
  $METADATA="stubb"
  PACT_ARGS="$PACT_ARGS -l $DEME -m $METADATA"
elif [[ $TIP_SELECTION_METHOD == "names" ]]
then
  PACT_ARGS="$PACT_ARGS -t $TIP_NAMES"
elif [[ $TIP_SELECTION_METHOD == "file" ]]
then
  PACT_ARGS="$PACT_ARGS -T $TIP_FILE"
fi


# TIME RANGE SELECTION
# ====================

if [[ $TIME_RANGE_SELECTOR == "mrca" ]]
then
  echo "XXX Still have to handle"
elif [[ $TIME_RANGE_SELECTOR == "custom" ]]
then
  # Still have to write the --strim-start for this into the wrapper
  PACT_ARGS="$PACT_ARGS -e $TIME_RANGE_END -S $TIME_RANGE_START"
fi


# RUN IT
# ======

pact_wrapper.py $PACT_ARGS
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

# Need this for csvkit features XXX
PATH="/home/csmall/pythedge-clstr/bin:$PATH"

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
plot_pact_tree.R $COMMON_ARGS parsed_pact_tree.csv $TREE_PLOT

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


