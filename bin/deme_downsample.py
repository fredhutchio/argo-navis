#!/usr/bin/env python
"""Given the clustering results of a run of alnclst, this tool takes those results and find a single
representative sequence for each cluster. In particular, it chooses the cluster representative closest to the
cluster center.
"""

import argparse
import random
import alnclst
from Bio import SeqIO


settings = dict(consensus_threshold=None, batches=10, max_iters=100)


def kmeans_runner(seqrecords, k):
    "Runs kmeans on seqrecords and picks representatives from each cluster, returning their names in a list."
    # Define clustering function we'll run batches number of times
    def clustering():
        return KMeansClsutering(seqrecords, k, settings['consensus_threshold'], settings['max_iters'])
    # Run the batches, and pick the one with the best convergence
    _, clusts = min((c.average_distance(), c) for c in (clustering() for i in
             xrange(settings['batches'])))
    # Pick the best representative for every cluster, and thow in clust_reps dict
    clust_reps = dict()
    for cluster_id, sequence, distance in clusts.mapping_iterator():
        current = (distance, sequence)
        clst_min = clust_reps.get(cluster_id, current)
        if current <= clst_min:
            clust_reps[cluster_id] = current
    return [seqname for (_, seqname) in clust_reps]


def random_runner(seqnames, k):
    "Randomly samples k seqnames from seqnames"
    if len(seqnames) < k:
        return seqnames
    else:
        return random.sample(seqnames, k)


def make_deme_map(deme_spec):
    "Turns deme metadata into a map of deme -> sequence names"
    deme_map = dict()
    for row in deme_spec:
        deme = row[args.deme_col]
        seqname = row['sequence']
        try:
            deme_map[deme].append(seqname)
        except KeyError:
            deme_map[deme] = [seqname]
    return deme_map


def get_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('alignment', type=argparse.FileType('r'), help="Alignment FASTA file")
    parser.add_argument('demes', type=argparse.FileType('r'), help="CSV metadata specifying deme info")
    parser.add_argument('-c', '--deme-col', help="Column specifying 'deme' argument in demes spec")
    parser.add_argument('-k', help="Maximum number of representatives for each deme")
    parser.add_argument('-m', '--method', choices=('random', 'kmeans'),
            help="Which downsampling method should be used")
    parser.add_argument('out_alignment', type=argparse.FileType('w'), help="Downsampled alignment output")
    parser.add_argument('out_demes', type=argparse.FileType('w'), help="Downsampled metadata output")
    return parser.parse_args()


def main():
    args = get_args()
    # Set random seed if needed
    if args.seed:
        random.seed(args.seed)

    # Create a lit of seqrecords to make things easier for ourselves
    seqrecords = SeqIO.do_dict(SeqIO.parse(alignment, 'fasta'))
    demes = list(csv.DictReader(args.clusters))

    # Turn our metadata into a map of deme -> seqnames
    deme_map = make_deme_map(demes)

    # Run the specified downsampling method for each deme, and gather kept representatives
    rep_seqnames = []
    for deme, seqnames in deme_map.iteritems():
        if args.method == 'random':
            deme_rep_seqnames = random_runner(seqnames, args.k)
        else:
            deme_sequences = [seqrecords[n] for n in seqnames]
            deme_rep_seqnames = kmeans_runner(deme_sequences, args.k)
        rep_seqnames += deme_rep_seqnames

    # Filter down the actual data based on representative names
    deme_rep_seqs = [seqrecords[n] for n in rep_seqnames]
    deme_rep_meta = [r for r in demes if r['sequence'] in deme_rep_seqs]

    out_demes = csv.DictWriter(args.out_demes, header=deme_rep_meta[0].keys())
    out_demes.write_header()
    out_demes.writerows(deme_rep_meta)

    SeqIO.write(deme_rep_seqs, args.out_alignment, 'fasta')

    for fh in [args.alignment, args.demes, args.out_alignment, args.out_demes]:
        fh.close()


if __name__ == '__main__':
    main()


