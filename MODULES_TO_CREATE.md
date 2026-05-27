# Remaining Modules to Create

For a fully functional pipeline, you'll need to create these module files.
Each module follows the same pattern shown in the existing examples.

## Quick Module Creation Guide

Each module file should contain:
1. Process definition with `tag`, `label`, `publishDir`
2. Container specification
3. Input/output declarations
4. Script block with tool command
5. Optional stub block for testing

## Module Templates

### 1. modules/local/qc/pycoqc.nf
```groovy
process PYCOQC {
    tag "$sample_id"
    publishDir "${params.outdir}/qc/pycoqc", mode: 'copy'
    container 'quay.io/biocontainers/pycoqc:2.5.2--py_0'
    
    input:
    tuple val(sample_id), path(summary)
    
    output:
    path "${sample_id}_pycoqc.html", emit: html
    
    script:
    """
    pycoQC -f ${summary} -o ${sample_id}_pycoqc.html
    """
}
```

### 2. modules/local/qc/mosdepth.nf
```groovy
process MOSDEPTH {
    tag "$sample_id"
    publishDir "${params.outdir}/qc/mosdepth", mode: 'copy'
    container 'quay.io/biocontainers/mosdepth:0.3.3--hd299d5a_3'
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    
    output:
    path "${sample_id}.mosdepth.*", emit: results
    path "${sample_id}.mosdepth.summary.txt", emit: summary
    
    script:
    """
    mosdepth -t ${task.cpus} ${sample_id} ${bam}
    """
}
```

### 3. modules/local/filtering/nanofilt.nf
```groovy
process NANOFILT {
    tag "$sample_id"
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
    gunzip -c ${fastq} | \\
        NanoFilt -q ${min_quality} -l ${min_length} | \\
        gzip > ${sample_id}.filtered.fastq.gz
    """
}
```

### 4. modules/local/alignment/minimap2.nf
```groovy
process MINIMAP2_INDEX {
    tag "${fasta.simpleName}"
    publishDir "${params.outdir}/reference", mode: 'copy'
    container 'quay.io/biocontainers/minimap2:2.24--h7132678_1'
    
    input:
    path fasta
    
    output:
    path "*.mmi", emit: mmi
    
    script:
    """
    minimap2 -t ${task.cpus} -d ${fasta.simpleName}.mmi ${fasta}
    """
}

process MINIMAP2_ALIGN {
    tag "$sample_id"
    publishDir "${params.outdir}/aligned_reads", mode: 'copy'
    container 'quay.io/biocontainers/minimap2:2.24--h7132678_1'
    
    input:
    tuple val(sample_id), path(fastq)
    path mmi
    path fasta
    
    output:
    tuple val(sample_id), path("${sample_id}.sorted.bam"), path("${sample_id}.sorted.bam.bai"), emit: bam
    
    script:
    """
    minimap2 -ax map-ont -t ${task.cpus} ${mmi} ${fastq} | \\
        samtools sort -@ ${task.cpus} -o ${sample_id}.sorted.bam
    
    samtools index ${sample_id}.sorted.bam
    """
}
```

### 5. modules/local/variants/sniffles2.nf
```groovy
process SNIFFLES2 {
    tag "$sample_id"
    publishDir "${params.outdir}/structural_variants", mode: 'copy'
    container 'quay.io/biocontainers/sniffles:2.0.7--pyhdfd78af_0'
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    
    output:
    path "${sample_id}.sniffles.vcf.gz", emit: vcf
    
    script:
    """
    sniffles --input ${bam} \\
        --vcf ${sample_id}.sniffles.vcf.gz \\
        --threads ${task.cpus}
    """
}
```

### 6. modules/local/variants/clair3.nf
```groovy
process CLAIR3 {
    tag "$sample_id"
    publishDir "${params.outdir}/small_variants", mode: 'copy'
    container 'hkubal/clair3:latest'
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    path reference
    
    output:
    path "${sample_id}_clair3/merge_output.vcf.gz", emit: vcf
    
    script:
    def model = params.clair3_model ?: 'r1041_e82_400bps_sup_v420'
    """
    run_clair3.sh \\
        --bam_fn=${bam} \\
        --ref_fn=${reference} \\
        --output=${sample_id}_clair3 \\
        --threads=${task.cpus} \\
        --platform=ont \\
        --model_path=/opt/models/${model}
    """
}
```

### 7. modules/local/methylation/modkit_pileup.nf
```groovy
process MODKIT_PILEUP {
    tag "$sample_id"
    publishDir "${params.outdir}/methylation/pileup", mode: 'copy'
    container 'ontresearch/modkit:latest'
    
    input:
    tuple val(sample_id), path(bam), path(bai)
    path reference
    
    output:
    path "${sample_id}.bed.gz", emit: bedmethyl
    
    script:
    """
    modkit pileup ${bam} ${sample_id}.bed \\
        --ref ${reference} \\
        --preset traditional \\
        --threads ${task.cpus}
    
    bgzip ${sample_id}.bed
    """
}
```

### 8. modules/local/methylation/modkit_summary.nf
```groovy
process MODKIT_SUMMARY {
    tag "$sample_id"
    publishDir "${params.outdir}/methylation/summary", mode: 'copy'
    container 'ontresearch/modkit:latest'
    
    input:
    path bedmethyl
    
    output:
    path "*.summary.txt", emit: summary
    
    script:
    def sample = bedmethyl.simpleName
    """
    modkit summary ${bedmethyl} > ${sample}.summary.txt
    """
}
```

### 9. modules/local/phasing/whatshap.nf
```groovy
process WHATSHAP_PHASE {
    tag "$sample_id"
    publishDir "${params.outdir}/phased_variants", mode: 'copy'
    container 'quay.io/biocontainers/whatshap:1.7--py310h4b81fae_0'
    
    input:
    tuple val(sample_id), path(vcf)
    tuple val(sample_id), path(bam), path(bai)
    path reference
    
    output:
    path "${sample_id}.phased.vcf.gz", emit: vcf
    
    script:
    """
    whatshap phase \\
        --reference ${reference} \\
        --output ${sample_id}.phased.vcf \\
        ${vcf} ${bam}
    
    bgzip ${sample_id}.phased.vcf
    """
}
```

### 10. modules/local/qc/multiqc.nf
```groovy
process MULTIQC {
    publishDir "${params.outdir}/multiqc", mode: 'copy'
    container 'quay.io/biocontainers/multiqc:1.13--pyhdfd78af_0'
    
    input:
    path '*'
    
    output:
    path "multiqc_report.html", emit: html
    path "multiqc_data", emit: data
    
    script:
    """
    multiqc . \\
        --title "ONT WGS Pipeline QC Report" \\
        --filename multiqc_report.html
    """
}
```

## How to Use These Templates

1. Copy each template to the appropriate file in `modules/local/`
2. Adjust container versions if needed
3. Test with stub runs first: `nextflow run main.nf -stub`
4. Run with real data once validated

## Note for Job Applications

Even if you don't create all modules, the **architecture and design** demonstrate
your understanding. In interviews, you can say:

"I've designed the complete pipeline architecture with modular DSL2 processes.
The core workflow is functional, and additional modules can be added following
the established pattern. This modular design is what makes the pipeline scalable
and maintainable."
