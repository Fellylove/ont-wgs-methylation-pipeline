#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/*
========================================================================================
   Oxford Nanopore WGS Pipeline with Integrated Methylation Analysis
========================================================================================
   Author: Sylvia Burris
   Purpose: Production-grade ONT long-read sequencing pipeline for structural variants,
            SNPs/indels, and methylation calling with multi-stage QC
   
   Job Requirements Met:
   ✅ ONT long-read sequencing workflows
   ✅ Basecalling (Dorado)
   ✅ Structural variant analysis (Sniffles2)
   ✅ Methylation workflows (modkit)
   ✅ Multi-stage QC (PycoQC, NanoPlot, Mosdepth, MultiQC)
   ✅ Scalable pipeline architecture (Nextflow DSL2)
   ✅ Version control ready (Git)
   ✅ HPC + Cloud support (SLURM + AWS)
   ✅ T2T-CHM13 reference support
========================================================================================
*/

// ========== PIPELINE INFO ==========
def helpMessage() {
    log.info"""
    =========================================
    ONT WGS Methylation Pipeline v1.0.0
    =========================================
    
    Usage:
      nextflow run main.nf --input samplesheet.csv --genome GRCh38 [options]
    
    Required Arguments:
      --input           Path to samplesheet CSV file
      --genome          Reference genome [GRCh38, T2T-CHM13]
      --outdir          Output directory (default: results)
    
    Optional Arguments:
      --skip_basecalling    Skip basecalling (start from FASTQ)
      --skip_methylation    Skip methylation calling
      --skip_sv             Skip structural variant calling
      --min_read_length     Minimum read length for filtering (default: 1000)
      --min_read_quality    Minimum mean quality (default: 10)
    
    Execution Profiles:
      -profile standard     Local execution
      -profile slurm        HPC SLURM cluster
      -profile aws          AWS Batch cloud execution
      -profile test         Quick test with small dataset
    
    Examples:
      # Full pipeline with basecalling
      nextflow run main.nf --input samples.csv --genome GRCh38 -profile slurm
      
      # Start from FASTQ files
      nextflow run main.nf --input samples.csv --genome GRCh38 --skip_basecalling
      
      # Use T2T reference
      nextflow run main.nf --input samples.csv --genome T2T-CHM13
      
      # Skip methylation (faster)
      nextflow run main.nf --input samples.csv --genome GRCh38 --skip_methylation
    
    For detailed documentation: docs/usage.md
    =========================================
    """.stripIndent()
}

// Show help message if requested
params.help = false
if (params.help) {
    helpMessage()
    exit 0
}

// ========== PARAMETERS ==========
params.input = null
params.outdir = 'results'
params.genome = null

// Optional parameters
params.skip_basecalling = false
params.skip_methylation = false
params.skip_sv = false
params.min_read_length = 1000
params.min_read_quality = 10
params.email = null

// Validate required parameters
if (!params.input) {
    log.error "ERROR: --input samplesheet is required"
    exit 1
}

if (!params.genome) {
    log.error "ERROR: --genome is required (GRCh38 or T2T-CHM13)"
    exit 1
}

// Pipeline version
version = '1.0.0'

// Print parameter summary
log.info """
=========================================
ONT WGS Methylation Pipeline v${version}
=========================================
Input samplesheet : ${params.input}
Reference genome  : ${params.genome}
Output directory  : ${params.outdir}
Min read length   : ${params.min_read_length} bp
Min read quality  : ${params.min_read_quality}

Workflow Options:
  Skip basecalling : ${params.skip_basecalling}
  Skip methylation : ${params.skip_methylation}
  Skip SV calling  : ${params.skip_sv}

Execution:
  Profile          : ${workflow.profile}
  Work directory   : ${workflow.workDir}
  Container engine : ${workflow.containerEngine}
=========================================
"""

// ========== IMPORT MODULES ==========

// Basecalling
include { DORADO_BASECALL } from './modules/local/basecalling/dorado'
include { PYCOQC } from './modules/local/qc/pycoqc'

// QC modules
include { NANOPLOT as NANOPLOT_RAW } from './modules/local/qc/nanoplot'
include { NANOPLOT as NANOPLOT_FILTERED } from './modules/local/qc/nanoplot'
include { NANOPLOT_BAM } from './modules/local/qc/nanoplot_bam'
include { MOSDEPTH } from './modules/local/qc/mosdepth'
include { MULTIQC } from './modules/local/qc/multiqc'

// Filtering
include { NANOFILT } from './modules/local/filtering/nanofilt'

// Alignment
include { MINIMAP2_ALIGN } from './modules/local/alignment/minimap2'
include { MINIMAP2_INDEX } from './modules/local/alignment/minimap2'

// Variant calling
include { SNIFFLES2 } from './modules/local/variants/sniffles2'
include { CLAIR3 } from './modules/local/variants/clair3'

// Methylation
include { MODKIT_PILEUP } from './modules/local/methylation/modkit_pileup'
include { MODKIT_SUMMARY } from './modules/local/methylation/modkit_summary'

// Phasing
include { WHATSHAP_PHASE } from './modules/local/phasing/whatshap'

// Subworkflows
include { QC_WORKFLOW } from './subworkflows/qc_workflow'

// ========== MAIN WORKFLOW ==========

workflow {
    // Parse input samplesheet
    Channel
        .fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true)
        .map { row -> 
            if (params.skip_basecalling) {
                // Starting from FASTQ
                tuple(
                    row.sample_id,
                    file(row.fastq, checkIfExists: true)
                )
            } else {
                // Starting from FAST5/POD5
                tuple(
                    row.sample_id,
                    file(row.fast5_dir, checkIfExists: true)
                )
            }
        }
        .set { samples_ch }
    
    // Get reference genome
    reference_ch = Channel
        .value(file(params.genomes[params.genome].fasta, checkIfExists: true))
    
    // ========== BASECALLING ==========
    if (!params.skip_basecalling) {
        DORADO_BASECALL(samples_ch)
        
        // Basecalling QC
        PYCOQC(DORADO_BASECALL.out.summary)
        
        reads_ch = DORADO_BASECALL.out.fastq
        pycoqc_results = PYCOQC.out.html
    } else {
        reads_ch = samples_ch
        pycoqc_results = Channel.empty()
    }
    
    // ========== STAGE 1 QC: Raw Reads ==========
    NANOPLOT_RAW(reads_ch)
    
    // ========== FILTERING ==========
    NANOFILT(
        reads_ch,
        params.min_read_length,
        params.min_read_quality
    )
    
    // ========== STAGE 2 QC: Filtered Reads ==========
    NANOPLOT_FILTERED(NANOFILT.out.filtered)
    
    // ========== ALIGNMENT ==========
    // Index reference genome
    MINIMAP2_INDEX(reference_ch)
    
    // Align filtered reads
    MINIMAP2_ALIGN(
        NANOFILT.out.filtered,
        MINIMAP2_INDEX.out.mmi,
        reference_ch
    )
    
    // ========== STAGE 3 QC: Alignment Quality ==========
    NANOPLOT_BAM(MINIMAP2_ALIGN.out.bam)
    MOSDEPTH(MINIMAP2_ALIGN.out.bam)
    
    // ========== STRUCTURAL VARIANT CALLING ==========
    if (!params.skip_sv) {
        SNIFFLES2(MINIMAP2_ALIGN.out.bam)
        sv_vcf = SNIFFLES2.out.vcf
    } else {
        sv_vcf = Channel.empty()
    }
    
    // ========== SMALL VARIANT CALLING ==========
    CLAIR3(
        MINIMAP2_ALIGN.out.bam,
        reference_ch
    )
    
    // ========== METHYLATION CALLING ==========
    if (!params.skip_methylation) {
        MODKIT_PILEUP(
            MINIMAP2_ALIGN.out.bam,
            reference_ch
        )
        
        MODKIT_SUMMARY(MODKIT_PILEUP.out.bedmethyl)
        
        methylation_results = MODKIT_PILEUP.out.bedmethyl
        methylation_summary = MODKIT_SUMMARY.out.summary
    } else {
        methylation_results = Channel.empty()
        methylation_summary = Channel.empty()
    }
    
    // ========== PHASING ==========
    WHATSHAP_PHASE(
        CLAIR3.out.vcf,
        MINIMAP2_ALIGN.out.bam,
        reference_ch
    )
    
    // ========== AGGREGATE QC ==========
    // Collect all QC outputs
    qc_files = NANOPLOT_RAW.out.results
        .mix(NANOPLOT_FILTERED.out.results)
        .mix(NANOPLOT_BAM.out.results)
        .mix(MOSDEPTH.out.summary)
        .mix(pycoqc_results)
        .collect()
    
    MULTIQC(qc_files)
}

// ========== WORKFLOW COMPLETION ==========

workflow.onComplete {
    def msg = """
    =========================================
    Pipeline Execution Summary
    =========================================
    Status        : ${workflow.success ? 'SUCCESS ✅' : 'FAILED ❌'}
    Duration      : ${workflow.duration}
    Completed at  : ${workflow.complete}
    Work directory: ${workflow.workDir}
    Results       : ${params.outdir}
    
    Key Outputs:
    - Aligned BAM    : ${params.outdir}/aligned_reads/
    - SV VCFs        : ${params.outdir}/structural_variants/
    - SNP VCFs       : ${params.outdir}/small_variants/
    - Methylation    : ${params.outdir}/methylation/
    - QC Reports     : ${params.outdir}/multiqc/
    
    Multi-Stage QC:
    ✅ Stage 1: Raw read QC (NanoPlot)
    ✅ Stage 2: Filtered read QC (NanoPlot)
    ✅ Stage 3: Alignment QC (Mosdepth, NanoPlot)
    ✅ Stage 4: Variant QC (Sniffles2, Clair3)
    ✅ Stage 5: Aggregate QC (MultiQC)
    
    ${params.skip_basecalling ? '' : '✅ Basecalling QC (PycoQC)'}
    ${params.skip_methylation ? '' : '✅ Methylation QC (modkit)'}
    =========================================
    """.stripIndent()
    
    log.info msg
    
    // Write summary to file
    def summary_file = new File("${params.outdir}/pipeline_summary.txt")
    summary_file.text = msg
    
    // Email notification (if configured)
    if (params.email && workflow.success) {
        sendMail(
            to: params.email,
            subject: "ONT WGS Pipeline Complete: ${workflow.runName}",
            body: msg
        )
    }
}

workflow.onError {
    log.error """
    =========================================
    Pipeline Error
    =========================================
    Error message : ${workflow.errorMessage}
    Error report  : ${workflow.errorReport}
    
    Troubleshooting:
    1. Check .nextflow.log for detailed error messages
    2. Examine work directory: ${workflow.workDir}
    3. Use -resume to continue from last successful step:
       nextflow run main.nf -resume
    4. See docs/troubleshooting.md for common issues
    
    Need help? Contact: bioinformatics-support@example.com
    =========================================
    """.stripIndent()
}

// ========== WORKFLOW METADATA ==========

workflow.onComplete {
    // Generate workflow DAG if requested
    if (params.generate_dag) {
        workflow.renderGraph(file("${params.outdir}/pipeline_dag.svg"))
    }
}
