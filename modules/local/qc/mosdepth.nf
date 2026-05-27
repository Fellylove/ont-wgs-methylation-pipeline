process MOSDEPTH {
    tag "$sample_id"
    label 'process_medium'
    publishDir "${params.outdir}/qc/mosdepth", mode: 'copy'
    
    container 'quay.io/biocontainers/mosdepth:0.3.3--hd299d5a_3'
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    
    output:
    path "${sample_id}.mosdepth.summary.txt", emit: summary
    path "${sample_id}.mosdepth.global.dist.txt", emit: dist
    path "${sample_id}.*", emit: results
    
    script:
    """
    mosdepth \
        --threads ${task.cpus} \
        --no-abbrev \
        ${sample_id} \
        ${bam}
    """
    
    stub:
    """
    touch ${sample_id}.mosdepth.summary.txt
    touch ${sample_id}.mosdepth.global.dist.txt
    """
}
