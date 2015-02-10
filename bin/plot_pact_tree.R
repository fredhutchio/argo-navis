#!/usr/bin/env Rscript

library(ggplot2)
library(argparse)
source('bin/common.R')

parser <- ArgumentParser()
parser$add_argument('input')
parser$add_argument('output')
args <- parser$parse_args()


data <- read.csv(args$input, stringsAsFactors=F)

# Factorify the demes and assign colors
deme.factor <- factorify.deme(data)
data <- deme.factor$data
deme.colors <- deme.factor$colors

# We will be doing a separate geom data setting for the tip coloring and such
tips.data <- subset(data, klass == "tip")

# Go to town plotting
gg <- ggplot(data, aes(x=x, y=y, color=label, fill=label))
gg <- gg + geom_segment(aes(xend=parent_x, yend=parent_y))
gg <- gg + scale_color_manual(values=deme.colors)
gg <- gg + geom_text(aes(x=x+0.01, y=y, label=name, hjust=0), color="black", size=1.8)
gg <- gg + geom_point(aes(color=label), data=tips.data)
gg <- gg + theme_bw()
gg <- gg + xlim(min(data$x), 0.1)
gg <- gg + theme(axis.text.y=element_blank(),
                 axis.ticks.y=element_blank(),
                 axis.title.y=element_blank(),
                 legend.position="none")
gg <- gg + xlab("evolutionary distance")

# Dynamically compute dimensions
n <- dim(tips.data)[1]
print(n)
height <- 9*(n/292) + 3

ggsave(args$output, gg, width=7, height=height)

