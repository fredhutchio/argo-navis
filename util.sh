#!/bin/bash

extify() {
    local REQ_EXT=$1
    shift

    local OUTPUT=""
    local FILE
    for FILE in $*; do
        local BASENAME=$(basename ${FILE})
        local EXT=${BASENAME##*.}
        if [[ ${EXT} != ${REQ_EXT} ]]; then
            local LINK="${BASENAME%%.*}.${REQ_EXT}"
            if [[ ! -f ${LINK} ]]; then
                ln -s ${FILE} ${LINK}
            fi
            FILE="${LINK}"
        fi
        OUTPUT="${OUTPUT} ${FILE}"
    done

    echo ${OUTPUT}
}

# from http://www.linuxjournal.com/content/use-date-command-measure-elapsed-time
timer() {
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local  stime=$1
        etime=$(date '+%s')

        if [[ -z "$stime" ]]; then stime=$etime; fi

        dt=$((etime - stime))
        ds=$((dt % 60))
        dm=$(((dt / 60) % 60))
        dh=$((dt / 3600))
        printf '%d:%02d:%02d' $dh $dm $ds
    fi
}

on_exit() {
    echo "Elapsed time: $(timer ${START_TIME})"
}

set -ex

MATSENGRP="/home/matsengrp/local"
export PATH="${MATSENGRP}/bin:${PATH}"
export LD_LIBRARY_PATH="${MATSENGRP}/lib:${MATSENGRP}/lib64:${MATSENGRP}/lib64/R/lib:${LD_LIBRARY_PATH}"
export PERL5LIB="${MATSENGRP}/lib/perl5:${PERL5LIB}"

set -u

START_TIME=$(timer)
trap on_exit EXIT
