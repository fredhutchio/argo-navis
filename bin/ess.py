#!/usr/bin/env python

import csv
import numpy
from biopy import bayesianStats as bs
import argparse
import re


commented_regex = re.compile("^\s*\#.*")

doc_template = """
<html>
<body>
    <h1>Effective Sample Size Results</h1>
    <p>Recommendation: {status}</p>

    <h2>Explanation</h2>
    <p>
        Ideally, you want all these values to be greater than or equal to 200.
        If any of them aren't, it's probably a good idea to do a "Resume" run, as described in the BEAST
        documentation.
        On average, running 3x as long will roughly increase your ESS by 3.
        This should help give you some sense of how much longer you should run BEAST.
    </p>

    <h2>Detailed Results</h2>
    <table>
        <tr><th>Parameter</th><th>ESS</th></tr>
        {table_content}
    </table>
</body>
</html>
"""

tr_template = "<tr><td>{parameter}</td><td>{ess}</td></tr>"


def dict_reader_to_cols(dict_reader):
    d = dict()
    for row in dict_reader:
        for k, v in row.iteritems():
            try:
                v = float(v)
                try:
                    d[k].append(v)
                except KeyError:
                    d[k] = [v]
            except ValueError:
                if k == "" and v == "":
                    # Don't worry about this, there is a tailing \t on each line
                    pass
                else:
                    # Otherwise... something weird is happening
                    print "Could not cast to float for kv pair:", k, v
    return d


def table_contents(results):
    trs = [tr_template.format(parameter=result[0], ess=result[1]) for result in results]
    return "\n".join(trs)


def html_contents(results):
    table_content = table_contents(results)
    within_tol = [x[1] > 200 for x in results]
    ess_good = all(within_tol)
    status = "Good to go" if all(within_tol) else "Should run longer"
    return doc_template.format(status=status, table_content=table_content)


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('logfile', type=argparse.FileType('r'))
    parser.add_argument('ess_out', type=argparse.FileType('w'))
    parser.add_argument('--html-out', action="store_true", help="Default is CSV output")
    return parser.parse_args()


def main(args):
    non_comment_lines = (row for row in args.logfile if not commented_regex.match(row))
    reader = csv.DictReader(non_comment_lines, delimiter="\t")
    data_columns = dict_reader_to_cols(reader)
    results = []
    for colname, data in data_columns.iteritems():
        results.append([colname, bs.effectiveSampleSize(data)])

    if args.html_out:
        html_content = html_contents(results)
        args.ess_out.write(html_content)
    else:
        writer = csv.writer(args.ess_out)
        writer.writerow(["statistic", "ess"])
        for result in results:
            writer.writerow(result)

    args.logfile.close()
    args.ess_out.close()


if __name__ == '__main__':
    main(get_args())


