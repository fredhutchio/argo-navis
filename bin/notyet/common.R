
idsFromMeta <- function(meta.fn) {
  meta <- read.csv(meta.fn, stringsAsFactors=F)
  return(meta$sequence)
}


clusterTips <- function(tre, ids, h) {
  ids <- intersect(ids, tre$tip.label)
  dists <- cophenetic(tre)
  dists <- dists[ids,ids]
  dists <- as.dist(dists)
  hc <- hclust(dists)
  cut <- cutree(hc, h=h)
  cut.df <- data.frame(sequence=names(cut), cluster.id=cut)
  cut.df$sequence <- as.character(cut.df$sequence)
  # Just keep one tip for each cluster
  keep.tips <- ddply(cut.df, .(cluster.id), function(df) df$sequence[1])$V1
  return(keep.tips)
}


## Deme coloring is rather tricky to accomplish in a general way... But all this is for that:

species <- c('bat', 'human', 'monkey', 'reference', 'rodent')
rodent.col <- rgb(134/225, 197/225, 140/225)
colors <- c(bats=rgb(0.857, 0.131, 0.132),
            bat =rgb(0.857, 0.131, 0.132),
            pig =rgb(147/225, 1.0, 1.0),
            pigs=rgb(147/225, 1.0, 1.0),
            humans=rgb(0.324, 0.609, 0.708),
            human =rgb(0.324, 0.609, 0.708),
            monkeys=rgb(0.765, 0.728, 0.274),
            monkey =rgb(0.765, 0.728, 0.274),
            rest     =rgb(0.394, 0.113, 0.593),
            reference=rgb(0.394, 0.113, 0.593),
            rodents=rodent.col,
            rodent =rodent.col
            )

factorify.deme <- function(df, label='label') {
  df <- df
  if (!class(df[,label]) == "character") {
    df[,label] <- sapply(df[,label], function(i) species[i])
    df[,label] <- factor(df[,label], levels=species)
  }
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

