#!/usr/bin/env python
import argparse
import csv
import re


coord_re = re.compile("\{([-\d\.]+),([-\d\.]+)\}")


def parse_rules(handle):
    # Returns a very raw and literal translation of the out.rules results from PACT
    def get_nodes(line):
        return [int(x) for x in line.split()]

    def int_if_intable(a):
        try:
            return int(a)
        except:
            return a

    def get_map(line, imgfn=int_if_intable):
        coll = (x.split('->') for x in line.split())
        return dict([(int_if_intable(a), imgfn(b)) for a, b in coll])

    def parse_coordinate(text):
        m = coord_re.match(text)
        return (float(m.group(1)), float(m.group(2)))

    tips = get_nodes(handle.next())
    trunk_nodes = get_nodes(handle.next())
    connections = get_map(handle.next())
    labels = get_map(handle.next())
    coordinates = get_map(handle.next(), parse_coordinate)
    tip_names  = get_map(handle.next(), str)
    return dict(tips=tips, trunk_nodes=trunk_nodes, connections=connections, labels=labels,
            coordinates=coordinates, tip_names=tip_names)


def get_row(parsed_tree, n_id):
    # This gives us the row data (as seen in final table) for the given n_id value
    if n_id in parsed_tree['tips']:
        klass = "tip"
        name = parsed_tree['tip_names'][n_id]
    else:
        klass = "trunk"
        name = ""
    try:
        parent_id = parsed_tree['connections'][n_id]
    except KeyError:
        parent_id = n_id
        klass = "root"
    label = parsed_tree['labels'][n_id]

    x, y = parsed_tree['coordinates'][n_id]
    parent_x, parent_y = parsed_tree['coordinates'][parent_id]

    return dict(id=n_id, klass=klass, name=name, parent_id=parent_id, x=x, y=y, parent_x=parent_x,
            parent_y=parent_y, label=label)


def parsed_to_table(parsed_tree):
    # Cols are going to be:
    #   id, parent_id, label, klass, name, x, y, parent_x, parent_y, 
    for n_id in parsed_tree['coordinates'].keys():
        yield get_row(parsed_tree, n_id)


def get_args():
    parser = argparse.ArgumentParser(prog="parse_pact_tree.py",
        description="""Utility for parsing the output of PACT into a form renderable by ggplot""")
    parser.add_argument('input', type=argparse.FileType('r'))
    parser.add_argument('output', type=argparse.FileType('w'))
    return parser.parse_args()


def main():
    # Get args, run the parser, spit out the results into a file
    args = get_args()
    data = parse_rules(args.input)

    writer = csv.DictWriter(args.output,
            fieldnames=["id", "parent_id", "label", "klass", "name", "x", "y", "parent_x", "parent_y"])
    writer.writeheader()

    for row in parsed_to_table(data):
        writer.writerow(row)

    args.input.close()
    args.output.close()


if __name__ == '__main__':
    main()



