#!/usr/bin/env python
"""
Formats a given BEAST XML file (possibly all ready to run) and respecifies te information needed to run the
classic Discrete trait.

Some things that would be nice:
* specify output files/formats (could let you run from root instead of the dir)
"""

from Bio import SeqIO
import xml.etree.ElementTree as ET
import argparse
import copy
import csv


def clear_children(node):
    "Element.remove doesn't seem to work the way it's supposed to, so we're doing this"
    node_attrib = copy.copy(node.attrib)
    node.clear()
    node.attrib = node_attrib


def set_alignment(xmldoc, alignment):
    aln_node = xmldoc.find('data')
    # First clear out the old alignment sequences
    clear_children(aln_node)
    print "seqs"
    for seq in aln_node:
        print seq
    # Next, construct and throw in the new sequence nodes
    for seq_record in alignment:
        seqid = seq_record.name
        ET.SubElement(aln_node, 'sequence',
                attrib=dict(id="seq_" + seqid,
                    taxon=seqid,
                    totalcount="4",
                    value=str(seq_record.seq)))


def deme(metarow):
    return metarow.get('deme') or metarow.get('community')


def set_traitset(xmldoc, metadata):
    trait_node = xmldoc.iter('traitSet').next()
    trait_string = ",\n".join([row['sequence'] + "=" + deme(row) for row in metadata])
    trait_node.text = trait_string


def set_mcmc(xmldoc, samples, sampling_interval):
    run_node = xmldoc.find('run')
    chain_length = samples * sampling_interval + 1
    run_node.set('chainLength', str(chain_length))
    loggers = run_node.findall('logger')
    for logger in loggers:
        logevery = sampling_interval * 10 if logger.get('id') == 'screenlog' else sampling_interval
        logger.set('logEvery', str(logevery))


def set_deme_count(xmldoc, metadata):
    demes = list(set(map(deme, metadata)))
    demes.sort()
    deme_count = len(demes)
    mig_dim = (deme_count - 1) * deme_count / 2
    for xpath in ['.//parameter[@id="relativeGeoRates.s:deme"]', './/stateNode[@id="rateIndicator.s:deme"]']:
        xmldoc.find(xpath).set('dimension', str(mig_dim))
    code_map = map(lambda ix: ix[1] + "=" + str(ix[0]), enumerate(demes))
    code_map = ",".join(code_map) + ",? = " + " ".join(map(str, range(deme_count))) + " "
    user_data_type_node = xmldoc.find('.//userDataType')
    user_data_type_node.set('codeMap', code_map)
    user_data_type_node.set('states', str(deme_count))
    trait_frequencies_param = xmldoc.find('.//frequencies/parameter[@id="traitfrequencies.s:deme"]')
    trait_frequencies_param.set('dimension', str(deme_count))
    trait_frequencies_param.text = str(1.0/deme_count)



def get_args():
    def int_or_floatify(string):
        return int(float(string))
    parser = argparse.ArgumentParser()
    parser.add_argument('template', type=argparse.FileType('r'),
            help="""A template BEAST XML (presumably created by Beauti) ready insertion of an alignment and
            discrete trait""")
    parser.add_argument('-a', '--alignment')
    parser.add_argument('-m', '--metadata', type=argparse.FileType('r'),
            help="Should contain 'community' column referencing the deme")
    parser.add_argument('-s', '--samples', type=int_or_floatify)
    parser.add_argument('-i', '--sampling-interval', type=int_or_floatify)
    parser.add_argument('beastfile', type=argparse.FileType('w'),
            help="Output BEAST XML file")
    return parser.parse_args()


def main(args):
    # Read in old data
    xmldoc = ET.parse(args.template)

    # Modify the data sets
    if args.alignment:
        alignment = SeqIO.parse(args.alignment, 'fasta')
        set_alignment(xmldoc, alignment)
    if args.metadata:
        metadata = list(csv.DictReader(args.metadata))
        set_traitset(xmldoc, metadata)
        # _could_ do something smart here where we look at which sequences in the XML file traitset that match
        # alignment passed in if _only_ alignment is passed in. Probably not worth it though...
        set_deme_count(xmldoc, metadata)

    set_mcmc(xmldoc, args.samples, args.sampling_interval)

    # Write the output
    xmldoc.write(args.beastfile)


if __name__ == '__main__':
    main(get_args())


