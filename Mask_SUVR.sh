#!/bin/bash

# Ensure FSL is initialized
if [ -z "$FSLDIR" ]; then
  echo "❌ Error: FSLDIR is not set. Please initialize FSL before running this script."
  exit 1
fi

# Path to MNI brain mask
BRAIN_MASK="$FSLDIR/data/standard/MNI152_T1_2mm_brain_mask.nii.gz"
if [ ! -f "$BRAIN_MASK" ]; then
  echo "❌ Error: MNI brain mask not found at $BRAIN_MASK"
  exit 1
fi

echo "🔍 Searching for all *_SUVR_2_MNI.nii.gz files..."
find . -type f -name "*_SUVR_2_MNI.nii.gz" | while read suvr_path; do
  suvr_dir=$(dirname "$suvr_path")
  suvr_file=$(basename "$suvr_path")
  suvr_base="${suvr_file%.nii.gz}"

  # --- Step 1: Apply Standard MNI Brain Mask ---
  output_path="${suvr_dir}/${suvr_base}_masked.nii.gz"

  echo "🧠 Masking with standard MNI mask: $suvr_path"
  echo "➡️ Output: $output_path"

  fslmaths "$suvr_path" -mas "$BRAIN_MASK" "$output_path"

  if [ -f "$output_path" ]; then
    echo "✅ Standard mask saved: $output_path"
  else
    echo "❌ Standard masking failed for $suvr_path"
    continue # Skip to next file if first masking fails
  fi
  
  echo "" # Spacer

  # --- Step 2: Apply Subject-Specific Gray Matter Mask (GMM) ---
  output_gmm_path="${suvr_dir}/${suvr_base}_masked_gmm.nii.gz"

  if [ ! -f "$output_gmm_path" ]; then
    echo "🧠 Applying subject-specific GMM..."

    # This assumes a directory structure like ./subjectID/... to find the mask
    subject_dir_root=$(echo "$suvr_path" | cut -d'/' -f2)

    # Define possible GMM filenames
    gmm_mask_path1="${subject_dir_root}/T1_gray_matter_mask_2_MNI.nii.gz"
    gmm_mask_path2="${subject_dir_root}/T1001_gray_matter_mask_2_MNI.nii.gz"
    gmm_mask_path="" # Initialize variable

    # Find the correct GMM file
    if [ -f "$gmm_mask_path1" ]; then
        gmm_mask_path="$gmm_mask_path1"
    elif [ -f "$gmm_mask_path2" ]; then
        gmm_mask_path="$gmm_mask_path2"
    fi

    # Check if a mask was found before proceeding
    if [ -n "$gmm_mask_path" ]; then
        echo "    Found GMM: $gmm_mask_path"
        echo "    ➡️  Output: $output_gmm_path"
        
        # Apply the GMM to the already-masked file
        fslmaths "$output_path" -mas "$gmm_mask_path" "$output_gmm_path"

        if [ -f "$output_gmm_path" ]; then
            echo "    ✅ GMM-masked SUVR saved."
        else
            echo "    ❌ GMM masking failed for $output_path"
        fi
    else
        echo "    ❌ ERROR: Could not find a Gray Matter Mask for this subject in '$subject_dir_root'. Skipping GMM step."
    fi
  else
    echo "✅ GMM-masked file already exists. Skipping."
  fi

  echo "" # Spacer
done

echo "✅ All SUVR images processed and masked."