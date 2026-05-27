process SNIFFLES2 {
    tag "$sample_id"
    label 'process_high'
    publishDir "${params.outdir}/structural_variants", mode: 'copy'
    
    container 'quay.io/biocontainers/sniffles:2.0.7--pyhdfd78af_0'
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    
    output:
    tuple val(sample_id), path("${sample_id}.sniffles.vcf.gz"), emit: vcf
    path "${sample_id}.sniffles.snf", emit: snf
    
    script:
    """
    sniffles \
        --input ${bam} \
        --vcf ${sample_id}.sniffles.vcf.gz \
        --snf ${sample_id}.sniffles.snf \
        --threads ${task.cpus} \
        --sample-id ${sample_id}
    
    echo "SV calling complete for ${sample_id}"
    """
    
    stub:
    """
    touch ${sample_id}.sniffles.vcf.gz
    touch ${sample_id}.sniffles.snf
    """
}
