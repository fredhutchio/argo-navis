#!/usr/bin/env python
"""Little script for parsing metadata out of sequence names given regular expressions. Supports parsing out
deme information and data information."""

import argparse
import csv
import re
from Bio import SeqIO


def get_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inseqs', help="Input sequences in fasta format")
    parser.add_argument('-d', '--deme-regex', required=True, type=re.compile,
            help="Regular expression with which to parse deme information")
    parser.add_argument('-t', '--time-regex', type=re.compile,
            help="Regular expression with which to parse date information")
    parser.add_argument('output', type=argparse.FileType('w'))
    return parser.parse_args()


def main():
    args = get_args()
    seqreader = SeqIO.parse(args.inseqs, 'fasta')

    header = ['sequence', 'deme']
    if args.time_regex:
        header.append('date')

    outwriter = csv.DictWriter(args.output, header)
    outwriter.writeheader()
    for seqrec in seqreader:
        seqname = seqrec.id
        deme = args.deme_regex.match(seqname).groups()[0]
        rowdict = dict(sequence=seqname, deme=deme)
        if args.time_regex:
            rowdict['date'] = re.time_regex.match(seqname).groups()[0]
        outwriter.writerow(rowdict)

    args.output.close()


if __name__ == '__main__':
    main()


