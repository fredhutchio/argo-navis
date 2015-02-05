#!/usr/bin/env python
"""
Formats a given BEAST XML file (possibly all ready to run) and respecifies the information needed to run the
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


def get_data_id(xmldoc):
    return xmldoc.find(".//data[@name='alignment'][@id]").attrib['id']


def deme(metarow):
    return metarow.get('deme') or metarow.get('community')


def set_deme(xmldoc, metadata):
    trait_node = xmldoc.iter('traitSet').next()
    trait_string = ",\n".join([row['sequence'] + "=" + deme(row) for row in metadata])
    trait_node.text = trait_string


def build_date_node(date_spec, data_id):
    date_node = ET.Element('trait',
            id='dateTrait.t:' + data_id,
            spec='beast.evolution.tree.TraitSet',
            traitname='date')
    date_node.text = date_spec
    taxa_node = ET.SubElement(date_node, 'taxa',
            id='TaxonSet.' + data_id,
            spec='TaxonSet')
    _ = ET.SubElement(taxa_node, 'data',
            idref=data_id,
            name="alignment")
    return date_node


def set_date(xmldoc, metadata, date_attr='date'):
    tree_node = xmldoc.find('.//state/tree')
    data_id = get_data_id(xmldoc)
    trait_string = ",\n".join([row['sequence'] + "=" + row[date_attr] for row in metadata])
    # This builds the base date node; more things need to be added
    date_node = build_date_node(trait_string, data_id)
    old_taxonset = tree_node.find("./taxonset")
    tree_node.insert(0, date_node)
    tree_node.remove(old_taxonset)
    new_taxonset = ET.SubElement(tree_node, "taxonset", idref="TaxonSet."+data_id)


def set_mcmc(xmldoc, samples, sampling_interval):
    run_node = xmldoc.find('run')
    # XXX Should really make it so that you only have to specify _one_, and it will find current value of
    # other
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
    parser.add_argument('-s', '--samples', type=int_or_floatify,
            help="Number of samples in output log file(s)")
    parser.add_argument('-d', '--deme-col',
            help="Specifies the deme column for metadata", default='deme')
    parser.add_argument('-D', '--date-col',
            help="If specified, will add a date specification to the output BEAST XML file")
    parser.add_argument('-i', '--sampling-interval', type=int_or_floatify,
            help="""Number of chain states to simulate between successive states samples for logfiles. The
            total chain length is therefor samples * sampling_interval.""")
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
        set_deme(xmldoc, metadata)
        # _could_ do something smart here where we look at which sequences in the XML file traitset that match
        # alignment passed in if _only_ alignment is passed in. Probably not worth it though...
        set_deme_count(xmldoc, metadata)
        if args.date_col:
            set_date(xmldoc, metadata, args.date_col)

    if args.samples or args.sampling_interval:
        set_mcmc(xmldoc, args.samples, args.sampling_interval)

    # Write the output
    xmldoc.write(args.beastfile)


if __name__ == '__main__':
    main(get_args())


