process NANOPLOT {
    tag "$sample_id"
    label "process_low"
    publishDir "${params.outdir}/qc/nanoplot", mode: "copy"

    container "quay.io/biocontainers/nanoplot:1.41.0--pyhdfd78af_0"

    input:
    tuple val(sample_id), path(reads)
    val prefix

    output:
    path "${sample_id}_${prefix}_NanoPlot-report.html", emit: html
    path "${sample_id}_${prefix}_NanoStats.txt", emit: stats
    path "${sample_id}_${prefix}*", emit: results

    script:
    """
    NanoPlot \
        --fastq ${reads} \
        --threads ${task.cpus} \
        --prefix ${sample_id}_${prefix}_ \
        --plots dot \
        --N50
    """

    stub:
    """
    touch ${sample_id}_${prefix}_NanoPlot-report.html
    touch ${sample_id}_${prefix}_NanoStats.txt
    """
}

process NANOPLOT_BAM {
    tag "$sample_id"
    label "process_low"
    publishDir "${params.outdir}/qc/nanoplot/aligned", mode: "copy"

    container "quay.io/biocontainers/nanoplot:1.41.0--pyhdfd78af_0"

    input:
    tuple val(sample_id), path(bam), path(bai)

    output:
    path "${sample_id}_aligned_NanoPlot-report.html", emit: html
    path "${sample_id}_aligned_NanoStats.txt", emit: stats
    path "${sample_id}_aligned*", emit: results

    script:
    """
    NanoPlot \
        --bam ${bam} \
        --threads ${task.cpus} \
        --prefix ${sample_id}_aligned_ \
        --plots dot \
        --N50
    """

    stub:
    """
    touch ${sample_id}_aligned_NanoPlot-report.html
    touch ${sample_id}_aligned_NanoStats.txt
    """
}
