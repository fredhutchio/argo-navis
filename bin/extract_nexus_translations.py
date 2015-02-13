#!/usr/bin/env python

import argparse
import csv
import re


begin_trees_re = re.compile('^Begin trees\;')
trans_token_re = re.compile('^\s*Translate')
trans_line_re = re.compile('^\s*(\d+)\s*([^\s\,]+)\,')
end_trans_re = re.compile("^\;$")


def translation_line_extraction_reducer(lines_and_state, next_line):
    "The reducer guts behind the extract_translation_lines state machine"
    lines, state = lines_and_state
    if state == "init":
        if begin_trees_re.match(next_line):
            return (lines, "begin_trees")
        else:
            return lines_and_state
    elif state == "begin_trees":
        if trans_token_re.match(next_line):
            return (lines, "in_trans")
        else:
            raise Exception, "Translation line should immediately procede Begin Trees"
    elif state == "in_trans":
        m = trans_line_re.match(next_line)
        if m:
            return (lines + [m.groups()], "in_trans")
        else:
            return (lines, "end_of_trans")
    elif state == "end_of_trans":
        if end_trans_re.match(next_line):
            return (lines, "finished")
        else:
            raise Exception, "Next line should have been an end of trans line"
    elif state == "finished":
        return lines_and_state
    else:
        raise Exception, "Unknown state: %s" % state


def extract_translation_lines(line_reader):
    """Basically a little state machine that marches through the nexus file, figures out when we're in the
    translation section, extracts those lines as 2-tuples of (int, seqname)."""
    lines, _ = reduce(translation_line_extraction_reducer, line_reader, ([], "init"))
    return lines


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('in_trees', type=argparse.FileType('r'))
    parser.add_argument('out_translation', type=argparse.FileType('w'))
    return parser.parse_args()


def main(args):
    writer = csv.writer(args.out_translation)
    writer.writerow(['id', 'sequence'])
    writer.writerows(extract_translation_lines(args.in_trees))
    args.in_trees.close()
    args.out_translation.close()


if __name__ == '__main__':
    main(get_args())


