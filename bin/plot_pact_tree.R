#!/usr/bin/env Rscript

library(ggplot2)
library(argparse)

parser <- ArgumentParser()
parser$add_argument('-b', '--brewer', help="Specify a color brewer pallete")
parser$add_argument('-c', '--color-spec', help="Specify a deme -> color CSV mapping")
parser$add_argument('-d', '--demes', help="For help with making colors consistent, always know what all the demes are")
parser$add_argument('common')
parser$add_argument('input')
parser$add_argument('output')
args <- parser$parse_args()

# Load shared library
source(args$common)

data <- read.csv(args$input, stringsAsFactors=F)

# Factorify the demes and assign colors
deme.factor <- factorify.deme(data, args=args)
data <- deme.factor$data
deme.colors <- deme.factor$colors

# We will be doing a separate geom data setting for the tip coloring and such
tips.data <- subset(data, klass == "tip")

# Computing some values for getting spacing/padding right for tips
x.range <- abs(min(data$x) - max(data$x))
x.end <- max(data$x) + (x.range * 0.13)
print(c(min(data$x), max(data$x), x.range, x.end))

# Move the tips names over just a touch from the dots
label.nudge <- x.range * 0.01


# Go to town plotting
gg <- ggplot(data, aes(x=x, y=y, color=label, fill=label))
gg <- gg + geom_segment(aes(xend=parent_x, yend=parent_y))
gg <- gg + scale_color_manual(values=deme.colors)
gg <- gg + geom_text(aes(x=x+label.nudge, y=y, label=sequence, hjust=0), color="black", size=1.8)
gg <- gg + geom_point(aes(color=label), data=tips.data)
gg <- gg + theme_bw()
# Add some padding for the label names on right
gg <- gg + xlim(min(data$x), x.end)
gg <- gg + theme(axis.text.y=element_blank(),
                 axis.ticks.y=element_blank(),
                 axis.title.y=element_blank(),
                 legend.position="none")
gg <- gg + xlab("time (units same as tip dates)")
gg <- gg + labs(title="Maximum likelihood ancestral reconstruction")

# Dynamically compute dimensions
n <- dim(tips.data)[1]
print(n)
height <- 9*(n/292) + 3

ggsave(args$output, gg, width=7, height=height)

