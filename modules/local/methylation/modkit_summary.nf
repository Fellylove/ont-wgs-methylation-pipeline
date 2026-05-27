process MODKIT_SUMMARY {
    tag "$sample_id"
    label 'process_low'
    publishDir "${params.outdir}/methylation/summary", mode: 'copy'
    
    container 'ontresearch/modkit:latest'
    
    input:
    tuple val(sample_id), path(bedmethyl)
    
    output:
    path "${sample_id}_methylation_summary.txt", emit: summary
    
    script:
    """
    modkit summary \
        ${bedmethyl} \
        > ${sample_id}_methylation_summary.txt
    
    echo "Methylation summary complete for ${sample_id}"
    """
    
    stub:
    """
    touch ${sample_id}_methylation_summary.txt
    """
}
