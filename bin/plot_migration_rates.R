#!/usr/bin/env Rscript

library(argparse)
library(ggplot2)
library(gtable)

parser <- ArgumentParser()
parser$add_argument('-b', '--brewer', help="Specify a color brewer pallete")
parser$add_argument('-c', '--color-spec', help="Specify a deme -> color CSV mapping")
parser$add_argument('-d', '--demes', help="For help with making colors consistent, always know what all the demes are")
parser$add_argument('common')
parser$add_argument('stats')
parser$add_argument('output')
args <- parser$parse_args()

# Load shared library
source(args$common)


stats <- read.delim(args$stats,
                    stringsAsFactors=F,
                    colClasses=c(mean='numeric', lower='numeric', upper='numeric'))


# Filter out just the paired migration statistics
stats <- stats[grepl("mig", stats$statistic),]
stats <- subset(stats, statistic != "mig_all")


# Now let's split this up a bit into mig_from and mig_to
mig.split <- strsplit(stats$statistic, "_")
stats$mig_from <- as.character(lapply(mig.split, function(x) x[2]))
stats$mig_to <- as.character(lapply(mig.split, function(x) x[3]))

deme.factor <- factorify.deme(stats, label='mig_from', args=args)
stats <- deme.factor$data
deme.colors <- deme.factor$colors


# Now for let there be plots
gg <- ggplot(stats)
gg <- gg + geom_crossbar(aes(x=mig_to, y=mean, ymin=lower, ymax=upper, fill=mig_from))
gg <- gg + facet_grid(mig_from ~ .)
gg <- gg + scale_fill_manual(values=deme.colors, name="source deme")
#gg <- gg + scale_y_sqrt()
gg <- gg + labs(y="")
gg <- gg + theme_bw()
gg <- gg + xlab("target deme")
gg <- gg + labs(title="Migration rate comparison")


# Render and save output; with the right hand facet labels on the left instead...
g <- ggplotGrob(gg)
g$layout[g$layout$name == "strip-right",c("l", "r")] <- 2
svg(args$output, width=5, height=4.3)
  grid.newpage()
  grid.draw(g)
dev.off()


