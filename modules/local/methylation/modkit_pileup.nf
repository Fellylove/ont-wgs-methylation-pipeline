process MODKIT_PILEUP {
    tag "$sample_id"
    label 'process_high'
    publishDir "${params.outdir}/methylation/pileup", mode: 'copy'
    
    container 'ontresearch/modkit:latest'
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    path reference
    
    output:
    tuple val(sample_id), path("${sample_id}.bed.gz"), emit: bedmethyl
    path "${sample_id}.bed.gz.tbi", emit: index
    
    script:
    """
    modkit pileup \
        ${bam} \
        ${sample_id}.bed \
        --ref ${reference} \
        --preset traditional \
        --threads ${task.cpus} \
        --log-filepath ${sample_id}_modkit.log
    
    bgzip ${sample_id}.bed
    tabix -p bed ${sample_id}.bed.gz
    
    echo "Methylation calling complete for ${sample_id}"
    """
    
    stub:
    """
    touch ${sample_id}.bed.gz
    touch ${sample_id}.bed.gz.tbi
    """
}
