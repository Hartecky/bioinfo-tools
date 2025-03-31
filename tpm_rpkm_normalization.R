calculate_tpm <- function(counts, len) {
  # Check that 'len' is a vector with one length per row in counts.
  if (length(len) != nrow(counts)) {
    stop("Length vector must have the same number of elements as rows in counts.")
  }
  
  # Calculate rates: counts divided by transcript length
  rates <- counts / len
  
  # Compute the sum of rates for each sample (column)
  scaling_factors <- colSums(rates, na.rm = TRUE)
  
  # Divide each value in rates by the column sum and multiply by 1e6
  tpm_matrix <- sweep(rates, 2, scaling_factors, FUN = "/") * 1e6
  
  # Convert to data frame and ensure column names are retained from counts
  TPKM <- as.data.frame(tpm_matrix)
  colnames(TPKM) <- colnames(counts)
  
  return(TPKM)
}

calculate_RPKM <- function(counts, len) {
  # Check that gene_length_kb has one value per row in counts
  if (length(len) != nrow(counts)) {
    stop("Length of gene_length_kb vector must equal number of rows in counts matrix.")
  }
  
  # Calculate total mapped reads for each sample (column sums)
  total_reads <- colSums(counts, na.rm = TRUE)
  
  # Divide counts by gene length (already in kilobases)
  counts_per_kb <- sweep(counts, MARGIN = 1, STATS = len, FUN = "/")
  
  # Normalize each column by the total reads and multiply by 1e6.
  # This gives: RPKM = (raw count / gene_length_in_kb) / (total_reads/1e6)
  RPKM <- sweep(counts_per_kb, MARGIN = 2, STATS = total_reads, FUN = "/") * 1e6
  
  return(RPKM)
}