#!/usr/bin/env python

import argparse
from os import path
import re
import os
import csv
import shutil
import subprocess


setting_template = """
# TREE MANIPULATION
{prune}

# TREE OUTPUT
print rule tree             # print out the fucking tree...

# SUMMARY STATS
summary tmrca               # time to mrca
summary proportions         # proportions on trunk of geneology
summary coal rates          # coalescent rates; separate for each label
summary mig rates           # migration rates; separate for each label pair
#summary fst                 # diversity between vs within labels

skyline settings -{sky_start} -{sky_end} {sky_interval}
skyline proportions
"""


def tips_from_label(meta_reader, label, deme_col="deme"):
    return [row['sequence'] for row in meta_reader if row[deme_col] == label]

def tips_from_labels(meta_reader, labels, deme_col="deme"):
    return [row['sequence'] for row in meta_reader if row[deme_col] in labels]

def translate_tips(tips, translation):
    result = list()
    for tip in tips:
        try:
            result.append(translation[tip])
        except KeyError:
            pass
    return result


def translation_from_nexus(handle):
    """This reads the seqname -> id translation from the trees file. Should probably eventually move this out
    and into a separate file so that we can use the results in plotting. Not now though..."""
    in_trans = False
    trans = dict()
    for line in handle:
        if re.search("Translate", line):
            # This is the demarkator for the translation section of the nexus file
            in_trans = True
            continue
        if in_trans:
            if re.match(";", line):
                # If we hit this, we've reached the end of the translation region
                break
            else:
                # Otherwise we're still in the Translate region, so populate trans
                index, name = line.strip().strip(',').split()
                trans[name] = index
    return trans


def prune_tips_string(tips, args):
    if args.translate_trees:
        trans = translation_from_nexus(file(args.trees_in))
        tips = translate_tips(tips, trans)
    return "prune to tips " + " ".join(tips)


def prune_string(args):
    if args.labels:
        if args.metadata:
            labels = args.labels.replace("\"", "").replace("'", "").split()
            print "Pruning to labels:", labels
            tips = tips_from_labels(csv.DictReader(args.metadata), labels, deme_col=args.deme_col)
            print "Tips for labels are:", tips
            return prune_tips_string(tips, args)
        else:
            return "prune to label " + args.labels

    elif args.tip_file or args.tips:
        if args.tip_file:
            tips = args.tip_file.read().split()
        else:
            tips = args.tips.split()
        return prune_tips_string(tips, args)
    else:
        return ""


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('trees_in')
    parser.add_argument('-t', '--tips', help="List of tips in quotes")
    parser.add_argument('-T', '--tip-file', help="File of tips sep by space", type=argparse.FileType('r'))
    parser.add_argument('-r', '--translate-trees', action="store_true", default=False,
        help="""If flagged, the trees_in file will be used for translating tip names from indices to actual
        tip names; this is necessary for BEAST runs only""")
    parser.add_argument('-m', '--metadata', type=argparse.FileType('r'),
        help="""Required for filtering by deme/label with the beast method""")
    parser.add_argument('-l', '--labels')
    parser.add_argument('-s', '--sky-start', default=2.0, type=float,
        help="How far back to compute skyline statistics (should be a potive number)")
    parser.add_argument('-S', '--trim-start', type=float,
        help="""Trim the tree from 0 back to the specified time; overrides sky-start for skyline plots.
        (should be a positive number)""")
    parser.add_argument('-e', '--trim-end', default=0.0, type=float,
        help="Most recent time to trim to in time interval; will also be used for sky (should be non-negative)")
    parser.add_argument('-o', '--out-dir')
    parser.add_argument('-p', '--prune-to-trunk', action="store_true", default=False)
    parser.add_argument('-d', '--deme-col', default="deme", help="Deme column in metadata file")
    return parser.parse_args()


def main():
    args = get_args()

    # Create the param file in the proper directory
    outfile = file(path.join(args.out_dir, 'in.param'), 'w')

    prune = prune_string(args)
    if args.prune_to_trunk:
        prune += "\nprune to trunk"

    if args.trim_start:
        prune += "\ntrim ends -%s -%s" % (args.trim_start, args.trim_end)

    sky_start = args.trim_start if args.trim_start else args.sky_start
    sky_end = args.trim_end
    sky_interval =  abs(sky_end - sky_start) / 100
    outfile.write(setting_template.format(
            prune=prune,
            sky_end=sky_end,
            sky_start=sky_start,
            sky_interval=sky_interval))
    outfile.close()

    # Copy the tree file over to the directory
    shutil.copyfile(args.trees_in, path.join(args.out_dir, 'in.trees'))

    # Actually run PACT
    os.chdir(args.out_dir)
    subprocess.check_call(['pact'])


if __name__ == '__main__':
    main()


