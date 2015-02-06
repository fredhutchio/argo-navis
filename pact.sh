#!/bin/bash

source $(dirname $0)/util.sh
source $1

# XXX uh... is this right?
export PATH=bin:argo_navis/bin:$PATH


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


