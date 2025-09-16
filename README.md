# T1 and PET Image Processing Pipeline

This repository contains a set of bash scripts designed to process T1-weighted MRI and PET scans (Amyloid and Tau). The pipeline performs skull-stripping, registration to MNI space, brain masking, and creation of group-average images.

## Prerequisites

- **FSL**: This pipeline is built entirely around FSL (FMRIB Software Library). You must have FSL installed and properly configured in your shell environment. The scripts will check for the `$FSLDIR` environment variable.

## Directory Structure

The scripts expect a specific directory structure for your data. All processing should be run from a root directory that contains individual subject folders. Each subject folder should be named with a numeric identifier (the scripts specifically look for 5-digit names like `20195`, `21160`, etc.).

The raw T1 and PET images should be placed within their respective subject folders. The scripts will generate all output files within these same folders.

**Example Structure:**

The scripts expect a specific directory structure. Each subject has a main folder (e.g., `20195`). Inside, the T1 scan is at the top level. PET scans should be in subdirectories named according to the tracer for the averaging scripts to work correctly.

- **PIB Amyloid PET:** Place these in a subdirectory in `PIB` .
- **AV45 Amyloid PET:** Place these in a subdirectory in `AV45`.
- **Tau PET:** Place these in a subdirectory named `tau`.

```
/path/to/your/project/
├── 20195/
│   ├─ T1001_float.nii.gz
│   └── amyloid/  
│   └───AV45/  # For AV45 scans
│       └── 20195_AV45_*_SUVR.nii.gz
├── 21160/
│   ├── T1001_float.nii.gz
│   └── tau/
│       └── 21160_TAU_*_SUVR.nii.gz
├── 22731/
│   ├── T1001_float.nii.gz
│.   └── amyloid/  
│   └───PIB/  # For PIB scans
│       └── 22731_PIB_*_SUV.nii.gz
├── process_t1.sh
├── Process_all_SUVR.sh
└── ... (other pipeline scripts)
```

## Processing Pipeline: Step-by-Step Guide

Follow these steps in order to correctly process your data.

### Step 1: Process Anatomical T1 Images

This is the foundational step that prepares the anatomical scans for use with the PET data.

- **Script:** `process_t1.sh`
- **Purpose:** For each subject, this script performs:
    1.  **Skull-stripping** on the T1 image.
    2.  **Tissue Segmentation** to identify gray matter.
    3.  **Non-linear Registration** of the T1 image to the MNI152 standard space template.
    4.  **Creates a Gray Matter Mask** in both native and MNI space.
- **How to use:**
  ```bash
  ./process_t1.sh
  ```
- **What you will get:**
    - `T1001_float_brain.nii.gz`: The skull-stripped T1 image.
    - `T1_to_MNI_warp.nii.gz`: The warp field for transforming from T1 to MNI space.
    - `T1_gray_matter_mask_2_MNI.nii.gz`: The subject's gray matter mask, now in MNI space. (This is optional)

### Step 2: Register PET Scans to MNI Space

This script uses the outputs from Step 1 to process all PET SUVR images.

- **Script:** `Process_all_SUVR.sh`
- **Purpose:** For each subject, this script finds all `*_SUVR.nii.gz` files and:
    1.  **Standardizes Orientation** of the PET scan to match the MNI template.
    2.  **Registers the PET scan** to the subject's own skull-stripped T1 image (from Step 1).
    3.  **Applies the T1-to-MNI warp field** (from Step 1) to the PET scan, bringing it into MNI space.
- **How to use:**
  ```bash
  ./Process_all_SUVR.sh
  ```
- **What you will get:**
    - `*_SUVR_2_MNI.nii.gz`: A copy of each PET SUVR scan, registered and normalized to MNI space.

### Step 3: Mask the Registered SUVR Images

This script applies brain masks to the SUVR images that are now in MNI space.

- **Script:** `Mask_SUVR.sh`
- **Purpose:** This script finds every `*_SUVR_2_MNI.nii.gz` file and applies two different masks:
    1.  A **standard MNI brain mask** to remove the skull and non-brain tissue.
    2.  The **subject-specific gray matter mask** (created in Step 1) to isolate the signal to gray matter regions. (This is optional to the result)
- **How to use:**
  ```bash
  ./Mask_SUVR.sh
  ```
- **What you will get:**
    - `*_SUVR_2_MNI_masked.nii.gz`: The SUVR image with the standard MNI brain mask applied.
    - `*_SUVR_2_MNI_masked_gmm.nii.gz`: The SUVR image with the subject-specific gray matter mask applied.(This is optional to the result)

### Step 4: Create Group-Average Images

After all subjects have been processed through the steps above, you can create average images for each tracer type.

- **Scripts:**
    - `Avg_av45Amy.sh` 
    - `Avg_PIBAmy.sh`
    - `Avg_tau.sh`
- **Purpose:** These scripts search for all the masked SUVR files for a specific tracer type across all subject directories, merge them into a single 4D file, and then compute the average image.
- **How to use:**
  ```bash
  # For AV45 Amyloid scans
  ./Avg_av45Amy.sh

  # For PIB Amyloid scans
  ./Avg_PIBAmy.sh

  # For Tau scans
  ./Avg_tau.sh
  ```
- **What you will get:**
    - `all_subjects_amyloid_average.nii.gz`: Average of all AV45 scans.
    - `pib_average.nii.gz`: Average of all PIB scans.
    - `tau_average.nii.gz`: Average of all Tau scans.
