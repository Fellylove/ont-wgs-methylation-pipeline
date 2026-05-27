process PYCOQC {
    tag "$sample_id"
    label 'process_low'
    publishDir "${params.outdir}/qc/pycoqc", mode: 'copy'
    
    container 'quay.io/biocontainers/pycoqc:2.5.2--py_0'
    
    input:
    tuple val(sample_id), path(summary)
    
    output:
    path "${sample_id}_pycoqc.html", emit: html
    path "${sample_id}_pycoqc.json", emit: json
    
    script:
    """
    pycoQC \
        -f ${summary} \
        -o ${sample_id}_pycoqc.html \
        -j ${sample_id}_pycoqc.json
    """
    
    stub:
    """
    touch ${sample_id}_pycoqc.html
    touch ${sample_id}_pycoqc.json
    """
}
