#!/bin/bash

# This script processes T1-weighted MRI images for a list of subjects.
# It performs skull-stripping, tissue segmentation, and registration to the MNI152 template.
# It intelligently skips steps and includes checks for segmentation failure and invalid masks.

# Set FSLDIR if it's not already set
export FSLDIR=${FSLDIR:-/usr/local/fsl}

# Find all 5-digit subject directories
for subject_dir in $(find . -maxdepth 1 -type d -name '[0-9][0-9][0-9][0-9][0-9]'); do
    echo "-----------------------------------------------------"
    echo "Processing subject directory: $subject_dir"

    # Find the T1 image
    t1_image=$(find "$subject_dir" -name 'T1001_*.nii.gz' | head -n 1)

    if [ -z "$t1_image" ]; then
        echo "  No T1 image found in $subject_dir. Skipping."
        continue
    fi

    echo "  Found T1 image: $t1_image"
    filename=$(basename "$t1_image")
    dir_name=$(dirname "$t1_image")

    # Strip .nii or .nii.gz extension
    if [[ "$filename" == *.nii.gz ]]; then
        base_name="${filename%.nii.gz}"
    elif [[ "$filename" == *.nii ]]; then
        base_name="${filename%.nii}"
    else
        base_name="$filename"
    fi

    # Define output filenames
    stripped_t1="${dir_name}/T1001_float_brain.nii.gz"
    t1_mni="${dir_name}/T1001_2_MNI_warped.nii.gz"
    gm_mask_native="${dir_name}/T1_gray_matter_mask.nii.gz"
    gm_mask_mni="${dir_name}/T1_gray_matter_mask_2_MNI.nii.gz"
    warp_field="${dir_name}/T1_to_MNI_warp"
    warp_field_file="${warp_field}.nii.gz" # Full filename for checking existence
    
    # --- Step 1: Skull-stripping (Prerequisite for all other steps) ---
    if [ ! -f "$stripped_t1" ]; then
        echo "  Running bet for skull-stripping..."
        bet "$t1_image" "$stripped_t1" -R -f 0.5 -g 0
    else
        echo "  - Skull-stripped brain already exists."
    fi
    if [ ! -f "$stripped_t1" ]; then
        echo "  ERROR: Skull-stripping failed or file not found. Skipping subject."
        continue
    fi

    # --- Step 2 & 3: T1 Registration (Runs only if final T1 is missing) ---
    if [ ! -f "$t1_mni" ]; then
        echo "  Running flirt for linear registration..."
        flirt -in "$stripped_t1" \
              -ref "$FSLDIR/data/standard/MNI152_T1_2mm_brain.nii.gz" \
              -omat "${dir_name}/T1_to_MNI.mat" \
              -out "${dir_name}/T1001_2_MNI_linear.nii.gz"

        echo "  Running fnirt for non-linear registration..."
        fnirt --in="$t1_image" \
              --aff="${dir_name}/T1_to_MNI.mat" \
              --ref="$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz" \
              --config=T1_2_MNI152_2mm \
              --cout="$warp_field" \
              --iout="$t1_mni"
    else
        echo "  - T1 in MNI space already exists. Skipping registration."
    fi
    if [ ! -f "$warp_field_file" ]; then
        echo "  ERROR: Warp field not found. Cannot create GM mask. Skipping subject."
        continue
    fi

    # --- NEW: Check if an existing mask is valid. If not, delete it for re-creation. ---
    if [ -f "$gm_mask_mni" ]; then
        max_val_mask=$(fslstats "$gm_mask_mni" -R | awk '{print $2}')
        if (( $(echo "$max_val_mask == 0" | bc -l) )); then
            echo "  ⚠️  Existing GM mask is empty. Deleting to trigger re-creation."
            rm "$gm_mask_mni"
        fi
    fi
    
    # --- Step 4, 5, & 6: GM Mask Creation (Runs only if final mask is missing OR was invalid) ---
    if [ ! -f "$gm_mask_mni" ]; then
        echo "  Running fast for tissue segmentation..."
        fast -t 1 -n 3 -g -o "${dir_name}/T1_seg" "$stripped_t1"

        fast_gm_output="${dir_name}/T1_seg_pve_1.nii.gz"
        if [ ! -f "$fast_gm_output" ]; then
            echo "  ❌ ERROR: FAST did not produce an output file. Skipping mask creation."
        else
            max_val=$(fslstats "$fast_gm_output" -R | awk '{print $2}')
            if (( $(echo "$max_val > 0.5" | bc -l) )); then
                echo "  Creating binary gray matter mask..."
                fslmaths "$fast_gm_output" -thr 0.5 -bin "$gm_mask_native"

                echo "  Warping gray matter mask to MNI space..."
                applywarp -i "$gm_mask_native" \
                          -r "$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz" \
                          -w "$warp_field" \
                          -o "$gm_mask_mni" \
                          --interp=nn
                echo "  ✅ Gray matter mask created."
            else
                echo "  ❌ ERROR: FAST segmentation failed (max GM probability = $max_val). Skipping mask creation for this subject."
            fi
        fi
    else
        echo "  - Valid gray matter mask in MNI space already exists. Skipping mask creation."
    fi
done

echo "-----------------------------------------------------"
echo "All subjects processed."