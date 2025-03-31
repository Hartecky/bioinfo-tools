library(GEOquery)
library(tidyverse)

get_geo_metadata <- function(geo_id) {
  metadata <- getGEO(GEO = geo_id, GSEMatrix = FALSE)
  metadata <- purrr::map(metadata@gsms, ~.x@header$characteristics_ch1) %>%
  stack() %>%
  tidyr::separate(values, into = c("feature", "value"), sep= ": ")%>%
  pivot_wider(names_from= feature, values_from = value) %>%
  janitor::clean_names()
 
  write.table(metadata, 
              file = paste(geo_id, "metadata.txt", sep = "_"),
              sep = "\t",
              col.names = TRUE,
              row.names = FALSE,
              quote = FALSE)
  
  return(metadata) 
}

meta <- get_geo_metadata("GSE60052")
