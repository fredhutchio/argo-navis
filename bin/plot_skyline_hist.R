#!/usr/bin/env Rscript

library(argparse)
library(ggplot2)

parser <- ArgumentParser()
parser$add_argument('-b', '--brewer', help="Specify a color brewer pallete")
parser$add_argument('-c', '--color-spec', help="Specify a deme -> color CSV mapping")
parser$add_argument('-d', '--demes', help="For help with making colors consistent, always know what all the demes are")
parser$add_argument('common')
parser$add_argument('input', help="Skyline outputs")
parser$add_argument('stats', help="Contains tmrca mean, which we use for cutting stats")
parser$add_argument('output')
args <- parser$parse_args()

# Load shared library
source(args$common)


data <- read.csv(args$input, stringsAsFactors=F, sep="\t")
stats.data <- read.csv(args$stats, stringsAsFactors=F, sep="\t")

tmrca.mean <- subset(stats.data, statistic == "tmrca")$mean

data <- subset(data, time > -tmrca.mean)
data$statistic <- gsub("pro_(.*)", "\\1", data$statistic)

deme.factor <- factorify.deme(data, label='statistic', args=args)
data <- deme.factor$data
deme.colors <- deme.factor$colors

gg <- ggplot(data, aes(x=time, y=mean, fill=statistic))
gg <- gg + geom_bar(stat="identity")
gg <- gg + scale_fill_manual(values=deme.colors, name="deme")
gg <- gg + theme_bw()
gg <- gg + xlab("evolutionary distance")
gg <- gg + ylab("ancestral deme proportion")
gg <- gg + labs(title="Skyline proportions histogram")

ggsave(args$output, gg, width=7, height=4.3)

