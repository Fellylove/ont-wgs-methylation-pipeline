process NANOFILT {
    tag "$sample_id"
    label 'process_low'
    publishDir "${params.outdir}/filtered", mode: 'copy'
    
    container 'quay.io/biocontainers/nanofilt:2.8.0--py_0'
    
    input:
    tuple val(sample_id), path(fastq)
    val min_length
    val min_quality
    
    output:
    tuple val(sample_id), path("${sample_id}.filtered.fastq.gz"), emit: filtered
    
    script:
    """
    gunzip -c ${fastq} | \
        NanoFilt \
            -q ${min_quality} \
            -l ${min_length} \
            --headcrop 50 | \
        gzip > ${sample_id}.filtered.fastq.gz
    
    echo "Filtering complete for ${sample_id}"
    echo "Parameters: min_quality=${min_quality}, min_length=${min_length}"
    """
    
    stub:
    """
    touch ${sample_id}.filtered.fastq.gz
    """
}
