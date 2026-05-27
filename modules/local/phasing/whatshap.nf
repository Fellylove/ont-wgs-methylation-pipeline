process WHATSHAP_PHASE {
    tag "$sample_id"
    label 'process_medium'
    publishDir "${params.outdir}/phased_variants", mode: 'copy'
    
    container 'quay.io/biocontainers/whatshap:1.7--py310h4b81fae_0'
    
    input:
    tuple val(sample_id), path(vcf)
    tuple val(sample_id), path(bam), path(bai)
    path reference
    
    output:
    tuple val(sample_id), path("${sample_id}.phased.vcf.gz"), emit: vcf
    path "${sample_id}.phasing_stats.txt", emit: stats
    
    script:
    """
    whatshap phase \
        --reference ${reference} \
        --output ${sample_id}.phased.vcf \
        --ignore-read-groups \
        ${vcf} \
        ${bam}
    
    bgzip ${sample_id}.phased.vcf
    tabix -p vcf ${sample_id}.phased.vcf.gz
    
    whatshap stats \
        ${sample_id}.phased.vcf.gz \
        > ${sample_id}.phasing_stats.txt
    
    echo "Phasing complete for ${sample_id}"
    """
    
    stub:
    """
    touch ${sample_id}.phased.vcf.gz
    touch ${sample_id}.phasing_stats.txt
    """
}
