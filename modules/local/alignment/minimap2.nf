process MINIMAP2_INDEX {
    tag "${fasta.simpleName}"
    label 'process_high'
    publishDir "${params.outdir}/reference", mode: 'copy'
    
    container 'quay.io/biocontainers/minimap2:2.24--h7132678_1'
    
    input:
    path fasta
    
    output:
    path "*.mmi", emit: mmi
    
    script:
    """
    minimap2 \
        -t ${task.cpus} \
        -d ${fasta.simpleName}.mmi \
        ${fasta}
    """
    
    stub:
    """
    touch ${fasta.simpleName}.mmi
    """
}

process MINIMAP2_ALIGN {
    tag "$sample_id"
    label 'process_high'
    publishDir "${params.outdir}/aligned_reads", mode: 'copy'
    
    container 'quay.io/biocontainers/minimap2:2.24--h7132678_1'
    
    input:
    tuple val(sample_id), path(fastq)
    path mmi
    path fasta
    
    output:
    tuple val(sample_id), path("${sample_id}.sorted.bam"), path("${sample_id}.sorted.bam.bai"), emit: bam
    path "${sample_id}.flagstat.txt", emit: flagstat
    
    script:
    """
    # Align reads
    minimap2 \
        -ax map-ont \
        -t ${task.cpus} \
        ${mmi} \
        ${fastq} | \
    samtools sort \
        -@ ${task.cpus} \
        -o ${sample_id}.sorted.bam
    
    # Index BAM
    samtools index ${sample_id}.sorted.bam
    
    # Mapping statistics
    samtools flagstat ${sample_id}.sorted.bam > ${sample_id}.flagstat.txt
    
    echo "Alignment complete for ${sample_id}"
    """
    
    stub:
    """
    touch ${sample_id}.sorted.bam
    touch ${sample_id}.sorted.bam.bai
    touch ${sample_id}.flagstat.txt
    """
}
