#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------
# Source configuration file

CONFIG_FILE="workflow.config"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    mkdir -p "$LOG_DIR"
else
    echo "Error: Configuration file '$CONFIG_FILE' not found!"
    exit 1
fi

#---------------------------------------------------------------------
# Logging function for informational messages
function log_info() {
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "[\033[1;34mINFO\033[0m] $timestamp: $*"
}

#---------------------------------------------------------------------
# Additional step: Run multiQC on a given input directory
function multiqc_control() {
    mkdir -p "$MULTIQC_DIR"
    multiqc "$1" -o "$MULTIQC_DIR"
}

#---------------------------------------------------------------------
# Step 01: Quality Control of Raw Reads
function quality_control_raw_reads() {
    # Check if the directory exists
    if [ ! -d "$RAW_READS_DIR" ]; then
        echo "ERROR: Directory '$RAW_READS_DIR' does not exist."
        return 1
    fi

    # Check if there is at least one fastq.gz file
    if ! ls -1 "$RAW_READS_DIR"/*.fastq.gz 1> /dev/null 2>&1; then
        echo "ERROR: No fastq.gz files found in '$RAW_READS_DIR'."
        return 1
    fi

    mkdir -p "$RAW_READS_QC_DIR"
    for file in "$RAW_READS_DIR"/*.fastq.gz; do
        if [ -f "$file" ]; then
            fastqc -t "$THREADS" "$file" -o "$RAW_READS_QC_DIR"
        fi
    done
}

#---------------------------------------------------------------------
# Step 02: Trimming Reads with Trimmomatic
function trim_reads() {
    mkdir -p "$CLEANED_READS_DIR"
    for input_forward in "$RAW_READS_DIR"/*_1.fastq.gz; do
        input_reverse="${input_forward/_1.fastq.gz/_2.fastq.gz}"
        output_forward_paired="$CLEANED_READS_DIR/$(basename "${input_forward/_1.fastq.gz/_1_trimmed.fastq.gz}")"
        output_reverse_paired="$CLEANED_READS_DIR/$(basename "${input_forward/_1.fastq.gz/_2_trimmed.fastq.gz}")"
        
        if ! TrimmomaticPE -threads "$THREADS" \
            "$input_forward" "$input_reverse" \
            "$output_forward_paired" /dev/null \
            "$output_reverse_paired" /dev/null \
            $TRIMMOMATIC_OPTIONS; then
            echo "ERROR: TrimmomaticPE failed on $(basename "$input_forward")" >&2
            return 1
        fi
        echo "Trimmed: $(basename "$input_forward") and $(basename "$input_reverse")"
    done
}

#---------------------------------------------------------------------
# Step 03: Quality Control of Trimmed Reads
function quality_control_trimmed_reads() {
    mkdir -p "$CLEANED_READS_QC_DIR"
    for file in "$CLEANED_READS_DIR"/*; do
        if [ -f "$file" ]; then
            fastqc -t "$THREADS" "$file" -o "$CLEANED_READS_QC_DIR"
        fi
    done
}

#---------------------------------------------------------------------
# Step 04: HISAT2 Alignment
function align_reads() {
    mkdir -p "$ALIGNED_READS_DIR"
    for input_forward in "$CLEANED_READS_DIR"/*_1_trimmed.fastq.gz; do
        input_reverse="${input_forward/_1_trimmed.fastq.gz/_2_trimmed.fastq.gz}"
        output_file="$ALIGNED_READS_DIR/$(basename "$input_forward" | cut -d'_' -f1).bam"
        hisat2 $HISAT2_OPTIONS -x "$REF_GENOME_INDEX" \
            -1 "$input_forward" -2 "$input_reverse" | \
            samtools view -@ "$THREADS" -Sbh > "$output_file"
        echo "Aligned: $(basename "$input_forward") and $(basename "$input_reverse")"
    done
}

#---------------------------------------------------------------------
# Step 05: Post-Alignment Processing (Sorting & Indexing)
function process_aligned_reads() {
    mkdir -p "$ALIGNED_READS_DIR/$ALIGNED_SORTED_DIR"
    for input_bam in "$ALIGNED_READS_DIR"/*.bam; do
        base=$(basename "$input_bam" .bam)
        sorted_bam="$ALIGNED_READS_DIR/$ALIGNED_SORTED_DIR/${base}.sorted.bam"
        samtools sort -@ "$THREADS" "$input_bam" -o "$sorted_bam"
        samtools index -@ "$THREADS" "$sorted_bam"
        echo "Processed: $(basename "$input_bam")"
    done
}

#---------------------------------------------------------------------
# Wrapper function to run a workflow step
function run_step() {
    local step_desc="$1"
    local log_file="$2"
    shift 2

    log_info "Starting: $step_desc"
    
    # Capture output from the command(s)
    local output
    if ! output=$("$@" 2>&1); then
        echo "$output" > "$log_file"
        log_info "ERROR: $step_desc failed. Log output:"
        echo "==== Log output for $step_desc ===="
        echo "$output"
        echo "=================================="
        exit 1
    else
        echo "$output" > "$log_file"
        log_info "Completed: $step_desc"
    fi
}

#---------------------------------------------------------------------
# Main Workflow Execution
function main() {
    log_info "Starting workflow..."

    run_step "Quality control (raw reads)" "$LOG_DIR/quality_control_raw_reads.log" quality_control_raw_reads
    run_step "MultiQC on raw reads" "$LOG_DIR/multiqc_raw_reads.log" multiqc_control "$RAW_READS_QC_DIR"
    run_step "Cleaning reads" "$LOG_DIR/trim_reads.log" trim_reads
    run_step "Quality control (cleaned reads)" "$LOG_DIR/quality_control_trimmed_reads.log" quality_control_trimmed_reads
    run_step "MultiQC on cleaned reads" "$LOG_DIR/multiqc_cleaned_reads.log" multiqc_control "$CLEANED_READS_QC_DIR"
    run_step "Reference genome alignment" "$LOG_DIR/align_reads.log" align_reads
    run_step "Post-alignment processing" "$LOG_DIR/process_aligned_reads.log" process_aligned_reads

    log_info "Workflow completed."
}

# Execute the main workflow
main
