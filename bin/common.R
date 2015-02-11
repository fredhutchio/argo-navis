"Mostly deme coloring specific codez"

library(RColorBrewer)


read.color.spec <- function(filename) {
  df <- read.csv(filename, stringsAsFactors=F)
  colors <- df$color
  names(colors) <- df$deme
  colors
}

brewify.colors <- function(demes, pallette="RdBu") {
  demes <- sort(unique(demes))
  n <- length(demes)
  colors <- brewer.pal(n, pallette)
  names(colors) <- demes
  colors
}

colors.from.args <- function(args) {
  if (!is.null(args$color_spec)) {
    return(read.color.spec(args$color_spec))
  } else if (!is.null(args$brewer)) {
    demes <- read.csv(args$demes, stringsAsFactors=F)$deme
    return(brewify.colors(demes, pallette=args$brewer))
  } else {
    stop("You must specify either --brewer or --color-spec")
  }
}

factorify.deme <- function(df, label='label', args=list()) {
  df <- df
  # Ugg... beast hacks, need to fix this upstream obviously
  #if (!class(df[,label]) == "character") {
    #rodent.col <- rgb(134/225, 197/225, 140/225)
    #species <- c('bat', 'human', 'monkey', 'reference', 'rodent')
    #df[,label] <- sapply(df[,label], function(i) species[i])
    #df[,label] <- factor(df[,label], levels=species)
  #}
  colors <- colors.from.args(args)
  keep.colors <- colors[as.character(sort(unique(df[,label])))]
  list(data=df, colors=keep.colors)
}


# Parsing, extraction and prettification of migration stat name info
mig.regex <- "mig_(.+)_(.+)"
comp.from <- function(stats.names) {
  gsub(mig.regex, "\\1", stats.names)
}
comp.to <- function(stats.names) {
  gsub(mig.regex, "\\2", stats.names)
}
pretty.mig <- function(stats.names) {
  gsub(mig.regex, "\\1 -> \\2", stats.names)
}
explode.mig <- function(df) {
  # Add some columns (from, to and migration) that make plotting and such easier
  df$from <- comp.from(df$statistic)
  df$migration <- pretty.mig(df$statistic)
  df$to <- comp.to(df$statistic)
  df$subset.name <- df$subset #hack to get ggplot's dynamic resolution not to break
  df
}

