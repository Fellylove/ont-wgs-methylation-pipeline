process DORADO_BASECALL {
    tag "$sample_id"
    label 'process_high'
    label 'gpu'
    publishDir "${params.outdir}/basecalled", mode: 'copy', pattern: "*.fastq.gz"
    publishDir "${params.outdir}/basecalling_summary", mode: 'copy', pattern: "*.txt"
    
    container 'ontresearch/dorado:latest'
    
    input:
    tuple val(sample_id), path(fast5_dir)
    
    output:
    tuple val(sample_id), path("${sample_id}.fastq.gz"), emit: fastq
    path "${sample_id}_sequencing_summary.txt", emit: summary
    path "${sample_id}_dorado.log", emit: log
    
    script:
    def model = params.dorado_model ?: 'dna_r10.4.1_e8.2_400bps_sup@v4.2.0'
    """
    # Basecall with Dorado (ONT's newest basecaller)
    dorado basecaller \\
        ${model} \\
        ${fast5_dir} \\
        --emit-fastq \\
        --device cuda:all \\
        > ${sample_id}.fastq \\
        2> ${sample_id}_dorado.log
    
    # Extract sequencing summary for QC
    dorado summary ${fast5_dir} > ${sample_id}_sequencing_summary.txt
    
    # Compress FASTQ
    gzip ${sample_id}.fastq
    
    echo "Basecalling completed for ${sample_id}"
    echo "Model used: ${model}"
    """
    
    stub:
    """
    touch ${sample_id}.fastq.gz
    touch ${sample_id}_sequencing_summary.txt
    touch ${sample_id}_dorado.log
    """
}
