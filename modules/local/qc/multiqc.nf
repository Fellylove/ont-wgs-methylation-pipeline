process MULTIQC {
    label 'process_low'
    publishDir "${params.outdir}/multiqc", mode: 'copy'
    
    container 'quay.io/biocontainers/multiqc:1.13--pyhdfd78af_0'
    
    input:
    path '*'
    
    output:
    path "multiqc_report.html", emit: html
    path "multiqc_data", emit: data
    
    script:
    """
    multiqc . \
        --title "ONT WGS Pipeline QC Report" \
        --filename multiqc_report.html
    """
    
    stub:
    """
    touch multiqc_report.html
    mkdir multiqc_data
    """
}
