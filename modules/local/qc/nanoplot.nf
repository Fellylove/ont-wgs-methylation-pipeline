process NANOPLOT {
    tag "$sample_id"
    label 'process_low'
    publishDir "${params.outdir}/qc/nanoplot/${stage}", mode: 'copy'
    
    container 'quay.io/biocontainers/nanoplot:1.41.0--pyhdfd78af_0'
    
    input:
    tuple val(sample_id), path(reads)
    val stage  // 'raw' or 'filtered'
    
    output:
    path "${sample_id}_NanoPlot-report.html", emit: html
    path "${sample_id}_NanoStats.txt", emit: stats
    path "${sample_id}_*.png", emit: plots, optional: true
    path "*", emit: results
    
    script:
    def input_flag = reads.name.endsWith('.gz') ? '--fastq' : '--fastq'
    """
    NanoPlot \\
        ${input_flag} ${reads} \\
        --threads ${task.cpus} \\
        --prefix ${sample_id}_ \\
        --plots dot \\
        --legacy hex \\
        --N50
    
    echo "QC completed for ${sample_id} (${stage} reads)"
    """
    
    stub:
    """
    touch ${sample_id}_NanoPlot-report.html
    touch ${sample_id}_NanoStats.txt
    """
}

process NANOPLOT_BAM {
    tag "$sample_id"
    label 'process_low'
    publishDir "${params.outdir}/qc/nanoplot/aligned", mode: 'copy'
    
    container 'quay.io/biocontainers/nanoplot:1.41.0--pyhdfd78af_0'
    
    input:
    tuple val(sample_id), path(bam)
    
    output:
    path "${sample_id}_aligned_NanoPlot-report.html", emit: html
    path "${sample_id}_aligned_NanoStats.txt", emit: stats
    path "${sample_id}_aligned_*.png", emit: plots, optional: true
    path "*", emit: results
    
    script:
    """
    NanoPlot \\
        --bam ${bam} \\
        --threads ${task.cpus} \\
        --prefix ${sample_id}_aligned_ \\
        --plots dot \\
        --N50
    
    echo "Alignment QC completed for ${sample_id}"
    """
    
    stub:
    """
    touch ${sample_id}_aligned_NanoPlot-report.html
    touch ${sample_id}_aligned_NanoStats.txt
    """
}
