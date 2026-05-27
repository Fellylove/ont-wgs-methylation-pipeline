# ONT WGS Pipeline - Module Creation Guide

This file contains all the module templates. Copy each section to create the individual module files.

## Directory Structure
```
modules/local/
├── basecalling/
│   └── dorado.nf (✅ Created)
├── qc/
│   ├── nanoplot.nf (✅ Created)  
│   ├── pycoqc.nf
│   ├── mosdepth.nf
│   └── multiqc.nf
├── filtering/
│   └── nanofilt.nf
├── alignment/
│   └── minimap2.nf
├── variants/
│   ├── sniffles2.nf
│   └── clair3.nf
├── methylation/
│   ├── modkit_pileup.nf
│   └── modkit_summary.nf
└── phasing/
    └── whatshap.nf
```

## Instructions for User
To complete the pipeline, create these files in the specified locations:
