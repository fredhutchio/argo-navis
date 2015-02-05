#!/usr/bin/env python

import argparse
import csv
import re


def ratio_tester(goal, left_out, left_in):
    new_base = left_out + left_in + 1
    def closeness(r):
        return abs(goal - r)
    return closeness((left_in + 1) / new_base) < closeness(left_in / new_base)

def 

def count_loglines(logfile):
    n = 0
    with open(logfile) as f:
        

def get_args():
    parser = argparse.ArgumentParser()
    parser$add_argument('-c', '--count', help="Count of log entries to keep in output")
    parser$add_argument('infile')
    parser$add_argument('outfile')
    return parser.parse_args()


def main(args):
    # do stuff
    pass


if __name__ == '__main__':
    main(get_args())


