#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/*
========================================================================================
   Oxford Nanopore WGS Pipeline with Integrated Methylation Analysis
========================================================================================
   Author: Sylvia Burris
*/

// ========== PARAMETERS ==========
params.help             = false
params.input            = null
params.outdir           = "results"
params.genome           = null
params.skip_basecalling = false
params.skip_methylation = false
params.skip_sv          = false
params.min_read_length  = 1000
params.min_read_quality = 10
params.email            = null
params.clair3_model     = "r1041_e82_400bps_sup_v420"

// ========== IMPORT MODULES ==========
include { DORADO_BASECALL }               from "./modules/local/basecalling/dorado"
include { PYCOQC }                        from "./modules/local/qc/pycoqc"
include { NANOPLOT as NANOPLOT_RAW }      from "./modules/local/qc/nanoplot"
include { NANOPLOT as NANOPLOT_FILTERED } from "./modules/local/qc/nanoplot"
include { NANOPLOT_BAM }                  from "./modules/local/qc/nanoplot"
include { MOSDEPTH }                      from "./modules/local/qc/mosdepth"
include { MULTIQC }                       from "./modules/local/qc/multiqc"
include { NANOFILT }                      from "./modules/local/filtering/nanofilt"
include { MINIMAP2_INDEX }                from "./modules/local/alignment/minimap2"
include { MINIMAP2_ALIGN }                from "./modules/local/alignment/minimap2"
include { SNIFFLES2 }                     from "./modules/local/variants/sniffles2"
include { CLAIR3 }                        from "./modules/local/variants/clair3"
include { MODKIT_PILEUP }                 from "./modules/local/methylation/modkit_pileup"
include { MODKIT_SUMMARY }                from "./modules/local/methylation/modkit_summary"
// include { WHATSHAP_PHASE }                from "./modules/local/phasing/whatshap"

// ========== HELP MESSAGE ==========
def helpMessage() {
    log.info """
    =========================================
    ONT WGS Methylation Pipeline v1.0.0
    =========================================
    Usage:
      nextflow run main.nf --input samplesheet.csv --genome GRCh38

    Required:
      --input           Path to samplesheet CSV
      --genome          Reference genome [GRCh38, T2T-CHM13]

    Optional:
      --outdir          Output directory (default: results)
      --skip_basecalling    Skip basecalling (start from FASTQ)
      --skip_methylation    Skip methylation calling
      --skip_sv             Skip structural variant calling
      --min_read_length     Minimum read length (default: 1000)
      --min_read_quality    Minimum quality score (default: 10)

    Profiles:
      -profile standard     Local execution
      -profile slurm        HPC SLURM cluster
      -profile aws          AWS Batch
      -profile test         Quick test

    Examples:
      nextflow run main.nf --input samples.csv --genome GRCh38 -profile slurm
      nextflow run main.nf --input samples.csv --genome GRCh38 --skip_basecalling
      nextflow run main.nf --input samples.csv --genome GRCh38 -resume
    =========================================
    """.stripIndent()
}

// ========== MAIN WORKFLOW ==========
workflow {

    // Show help and exit
    if (params.help) {
        helpMessage()
        exit 0
    }

    // Validate required parameters
    if (!params.input) {
        error "ERROR: --input samplesheet is required"
    }
    if (!params.genome) {
        error "ERROR: --genome is required (GRCh38 or T2T-CHM13)"
    }

    // Print pipeline info
    log.info """
    =========================================
    ONT WGS Methylation Pipeline v1.0.0
    =========================================
    Input        : ${params.input}
    Genome       : ${params.genome}
    Output       : ${params.outdir}
    Skip basecall: ${params.skip_basecalling}
    Skip methyl  : ${params.skip_methylation}
    Skip SV      : ${params.skip_sv}
    Profile      : ${workflow.profile}
    Work dir     : ${workflow.workDir}
    =========================================
    """.stripIndent()

    // ===== PARSE INPUT SAMPLESHEET =====
    Channel
        .fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true)
        .map { row ->
            if (params.skip_basecalling) {
                tuple(row.sample_id, file(row.fastq, checkIfExists: true))
            } else {
                tuple(row.sample_id, file(row.fast5_dir, checkIfExists: true))
            }
        }
        .set { samples_ch }

    // ===== GET REFERENCE GENOME =====
    reference_ch = Channel
        .value(file(params.genomes[params.genome].fasta, checkIfExists: true))

    // ===== BASECALLING =====
    if (!params.skip_basecalling) {
        DORADO_BASECALL(samples_ch)
        PYCOQC(DORADO_BASECALL.out.summary)
        reads_ch  = DORADO_BASECALL.out.fastq
        pycoqc_ch = PYCOQC.out.html
    } else {
        reads_ch  = samples_ch
        pycoqc_ch = Channel.empty()
    }

    // ===== STAGE 1 QC: Raw Reads =====
    NANOPLOT_RAW(reads_ch, "raw")

    // ===== FILTERING =====
    NANOFILT(reads_ch, params.min_read_length, params.min_read_quality)

    // ===== STAGE 2 QC: Filtered Reads =====
    NANOPLOT_FILTERED(NANOFILT.out.filtered, "filtered")

    // ===== ALIGNMENT =====
    MINIMAP2_INDEX(reference_ch)

    MINIMAP2_ALIGN(
        NANOFILT.out.filtered,
        MINIMAP2_INDEX.out.mmi,
        reference_ch
    )

    // ===== STAGE 3 QC: Alignment =====
    NANOPLOT_BAM(MINIMAP2_ALIGN.out.bam)
    MOSDEPTH(MINIMAP2_ALIGN.out.bam)

    // ===== STRUCTURAL VARIANT CALLING =====
    if (!params.skip_sv) {
        SNIFFLES2(MINIMAP2_ALIGN.out.bam)
        sv_ch = SNIFFLES2.out.vcf
    } else {
        sv_ch = Channel.empty()
    }

    // ===== SMALL VARIANT CALLING =====
    CLAIR3(MINIMAP2_ALIGN.out.bam, reference_ch)

    // ===== METHYLATION CALLING =====
    if (!params.skip_methylation) {
        MODKIT_PILEUP(MINIMAP2_ALIGN.out.bam, reference_ch)
        MODKIT_SUMMARY(MODKIT_PILEUP.out.bedmethyl)
        methyl_ch = MODKIT_PILEUP.out.bedmethyl
    } else {
        methyl_ch = Channel.empty()
    }

    // ===== PHASING (skipped - fixing container) =====

    // ===== STAGE 4 QC: Aggregate =====
    qc_files = NANOPLOT_RAW.out.results
        .mix(NANOPLOT_FILTERED.out.results)
        .mix(NANOPLOT_BAM.out.results)
        .mix(MOSDEPTH.out.summary)
        .mix(pycoqc_ch)
        .collect()

    MULTIQC(qc_files)
}
