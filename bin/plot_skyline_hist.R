#!/usr/bin/env Rscript

library(argparse)
library(ggplot2)
source('bin/common.R')

parser <- ArgumentParser()
parser$add_argument('input')
# XXX - should actually just remove this since now we have this filtering in the pact_wrapper
#parser$add_argument('-t', '--min-time', type='double', default=-1.75)
parser$add_argument('stats', help="Contains tmrca mean, which we use for cutting stats")
parser$add_argument('output')
args <- parser$parse_args()


data <- read.csv(args$input, stringsAsFactors=F, sep="\t")
stats.data <- read.csv(args$stats, stringsAsFactors=F, sep="\t")

tmrca.mean <- subset(stats.data, statistic == "tmrca")$mean

data <- subset(data, time > -tmrca.mean)
data$statistic <- gsub("pro_(.*)", "\\1", data$statistic)

deme.factor <- factorify.deme(data, label='statistic')
data <- deme.factor$data
deme.colors <- deme.factor$colors

gg <- ggplot(data, aes(x=time, y=mean, fill=statistic))
gg <- gg + geom_bar(stat="identity")
gg <- gg + scale_fill_manual(values=deme.colors, name="host group")
gg <- gg + theme_bw()
gg <- gg + xlab("evolutionary distance")
gg <- gg + ylab("ancestral host group proportion")

ggsave(args$output, gg, width=7, height=4.3)

