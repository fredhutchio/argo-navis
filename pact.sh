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

OUT_RULES="$WORK_DIR/out.rules"
OUT_STATS="$WORK_DIR/out.stats"
OUT_SKYLINES="$WORK_DIR/out.skylines"



# PLOTTING RESULTS
# ================

# Parse the out.rules file and make a tree plots of it
TREE_PLOT="tree_plot.svg"
parse_pact_tree.py $OUT_RULES parsed_pact_tree.csv
plot_pact_tree.R parsed_pact_tree.csv $TREE_PLOT

# Make skyline plot
SKYLINE_PLOT="skyline_plot.svg"
plot_skyline_hist.R $OUT_SKYLINES $SKYLINE_PLOT

# Do migration rate plot
MIGRATION_RATES_PLOT="migration_rates_plot.svg"
plot_migration_rates.R $OUT_STATS $MIGRATION_RATES_PLOT

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
svg_stack.py --direction="v" $TITLE $MAIN | \
  inkscape --without-gui --export-pdf=$FIGURES /dev/stdin


# sketch:
# * compute color spec
# * format pact file
#   * parse rules
#     * plot
#   * plot skylines
#   * migrate extract
#     * plot
#     * table? [out]
#   * grab all things that have data
#     * zip [out]
#   * combine plots [out]

