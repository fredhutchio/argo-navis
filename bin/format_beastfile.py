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
    """This function replaces the alignment data in xmldoc with that from sequences in alignment."""
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
    """The data set will have a given name, assigned by BEAUti, typically based on the named of the data file
    loaded into it. This name gets referred to in a number of places (presumably so there can be a number of
    partitions/datasets in an analysis), and is needed by other bits of code that do their thing."""
    return xmldoc.find(".//data[@name='alignment'][@id]").attrib['id']


def default_deme_getter(metarow):
    """A default function for getting the deme data from a given metadata row. Specifically defaults to 'deme'
    first, then to 'community' next. Returns none if it doesn't find either."""
    return metarow.get('deme') or metarow.get('community')


def set_deme(xmldoc, metadata, deme_getter=default_deme_getter):
    """Sets the deme information of the xmldoc based on metadata, and using the deme_getter (by default the
    `default_deme_getter` function above."""
    trait_node = xmldoc.iter('traitSet').next()
    trait_string = ",\n".join([row['sequence'] + "=" + deme_getter(row) for row in metadata])
    trait_node.text = trait_string


def build_date_node(date_spec, data_id):
    """Builds a node of date traits, given the date_spec string which is the actual string representation of
    the sequence -> date mapping. Has to create a `taxa` subnode, and a `data` subnode of that, which points
    to the data set in question via `idref`.""" 
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
    """Builds a dateTrait node via `build_date_node` above, and inserts into the `.//state/tree` node.
    However, this `tree` node already contains a `taxonset` node which has a `data` node, and this
    `taxonset` node has the same id as the `taxa` node in the the date `trait` node. As such, the node that
    _was_ present must be removed, so that we don't get a duplicate id error. Instead, we replace the old
    taxonset node with one which has an `idref` pointing to the `taxa` node inside the `trait` node. This is
    rather convoluted, and I'm not possible that some file with multiple datasets wouldn't break on this, but
    this described strategy seems to work for now."""
    # First get our tree node; we'll be adding the date data to this
    tree_node = xmldoc.find('.//state/tree')
    # Construct our trait string, just as we do for `set_deme`
    trait_string = ",\n".join([row['sequence'] + "=" + row[date_attr] for row in metadata])
    # Build the date trait node, and carry out all the weird mucking to get the new `taxonset` node in, as
    # described in the docstring
    data_id = get_data_id(xmldoc)
    date_node = build_date_node(trait_string, data_id)
    old_taxonset = tree_node.find("./taxonset")
    tree_node.insert(0, date_node)
    tree_node.remove(old_taxonset)
    new_taxonset = ET.SubElement(tree_node, "taxonset", idref="TaxonSet."+data_id)


def get_current_interval(xmldoc):
    run_node = xmldoc.find('run')
    loggers = run_node.findall('logger')
    intervals = list(set([int(l.get('logEvery')) for l in loggers if l.get('id') != 'screenlog']))
    if len(intervals) > 1:
        raise "Cannot get an interval for this xml doc; there are multiple such values"
    return intervals[0]


def set_mcmc(xmldoc, samples, sampling_interval):
    "Sets the MCMC chain settings (how often to log, how long to run, etc"
    run_node = xmldoc.find('run')
    # XXX Should really make it so that you only have to specify _one_, and it will find current value of
    # other so that chain length doesn't break.
    chain_length = samples * sampling_interval + 1
    run_node.set('chainLength', str(chain_length))
    loggers = run_node.findall('logger')
    for logger in loggers:
        logevery = sampling_interval * 10 if logger.get('id') == 'screenlog' else sampling_interval
        logger.set('logEvery', str(logevery))


def normalize_filenames(xmldoc, logger_filename="posterior.log", treefile_filename="posterior.trait.trees"):
    run_node = xmldoc.find('run')
    logfile_node = run_node.find('logger[@id="tracelog"]')
    treefile_node = run_node.find('logger[@id="treeWithTraitLogger.deme"]')
    logfile_node.set('fileName', logger_filename)
    treefile_node.set('fileName', treefile_filename)


def set_deme_count(xmldoc, metadata, deme_getter=default_deme_getter):
    "Updates the model specs based onthe number of demes in the data set."
    demes = list(set(map(deme_getter, metadata)))
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
            discrete trait.""")
    parser.add_argument('-a', '--alignment',
            help="Replace alignment in beast file with this alignment; Fasta format.")
    parser.add_argument('-m', '--metadata', type=argparse.FileType('r'),
            help="Should contain 'community' column referencing the deme.")
    parser.add_argument('-s', '--samples', type=int_or_floatify,
            help="Number of samples in output log file(s).")
    parser.add_argument('-d', '--deme-col',
            help="""Specifies the deme column for metadata; defaults to deme or community (whichever is present)
            if not specified.""")
    parser.add_argument('-D', '--date-col',
            help="If specified, will add a date specification to the output BEAST XML file.")
    parser.add_argument('-i', '--sampling-interval', type=int_or_floatify,
            help="""Number of chain states to simulate between successive states samples for logfiles. The
            total chain length is therefor samples * sampling_interval.""")
    parser.add_argument('beastfile', type=argparse.FileType('w'),
            help="Output BEAST XML file.")
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
        # Set the deme getter
        deme_getter = lambda row: row[args.deme_col] if args.deme_col else default_deme_getter(row)
        set_deme(xmldoc, metadata, deme_getter)
        # _could_ do something smart here where we look at which sequences in the XML file traitset that match
        # alignment passed in if _only_ alignment is passed in. Probably not worth it though...
        set_deme_count(xmldoc, metadata, deme_getter)
        if args.date_col:
            set_date(xmldoc, metadata, args.date_col)

    if args.samples or args.sampling_interval:
        interval = args.sampling_interval if args.sampling_interval else get_current_interval(xmldoc)
        set_mcmc(xmldoc, args.samples, interval)

    # Make sure that we always have the same file names out. These are specified as defaults of the function,
    # but could be customized here or through the cl args if needed.
    normalize_filenames(xmldoc)

    # Write the output
    xmldoc.write(args.beastfile)


if __name__ == '__main__':
    main(get_args())


