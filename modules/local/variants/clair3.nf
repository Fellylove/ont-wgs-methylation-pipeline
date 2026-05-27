process CLAIR3 {
    tag "$sample_id"
    label 'process_high'
    publishDir "${params.outdir}/small_variants", mode: 'copy'
    
    container 'hkubal/clair3:latest'
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    path reference
    
    output:
    tuple val(sample_id), path("${sample_id}_clair3/merge_output.vcf.gz"), emit: vcf
    path "${sample_id}_clair3/", emit: dir
    
    script:
    def model = params.clair3_model ?: 'r1041_e82_400bps_sup_v420'
    """
    run_clair3.sh \
        --bam_fn=${bam} \
        --ref_fn=${reference} \
        --output=${sample_id}_clair3 \
        --threads=${task.cpus} \
        --platform=ont \
        --model_path=/opt/models/${model}
    
    echo "Small variant calling complete for ${sample_id}"
    """
    
    stub:
    """
    mkdir -p ${sample_id}_clair3
    touch ${sample_id}_clair3/merge_output.vcf.gz
    """
}
