#!/bin/bash

# Script to process PET images, registering them to T1 and then to MNI space.
# Includes orientation standardization to ensure robust registration.

# Ensure FSL is initialized
if [ -z "$FSLDIR" ]; then
  echo "Error: FSLDIR environment variable is not set. Please initialize FSL."
  exit 1
fi

# Set the MNI standard brain path
MNI_STANDARD_BRAIN="$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz"
if [ ! -f "$MNI_STANDARD_BRAIN" ]; then
  echo "Error: MNI standard brain not found at $MNI_STANDARD_BRAIN"
  exit 1
fi

echo "Starting processing..."

# Loop through all directories with 5-digit names
for subject_dir in [0-9][0-9][0-9][0-9][0-9]/; do
  subject_id=$(basename "$subject_dir")
  echo "-----------------------------------------------------"
  echo "Checking subject: $subject_id"

  # Define required file paths
  warp_field="${subject_dir}T1_to_MNI_warp.nii.gz"
  t1_brain=$(find "$subject_dir" -maxdepth 1 -name "T1001_*_brain.nii.gz" | head -n 1)

  # Check required files
  if [ ! -f "$warp_field" ] || [ ! -f "$t1_brain" ]; then
    echo "Skipping subject $subject_id: Missing T1 warp field or brain file."
    continue
  fi

  # Find all PET SUVR scans
  find "$subject_dir" -type f -name "*_SUVR.nii.gz" | while read pet_scan_path; do
    echo "  Processing PET scan: $pet_scan_path"

    # Define derived file names with  suffix
    pet_dir=$(dirname "$pet_scan_path")
    pet_basename=$(basename "$pet_scan_path" .nii.gz)

    pet_to_t1_mat="${pet_dir}/${pet_basename}_to_T1.mat"
    pet_to_t1_nii="${pet_dir}/${pet_basename}_to_T1.nii.gz"
    final_output_nii="${pet_dir}/${pet_basename}_2_MNI.nii.gz"

    # Skip if final _copy output already exists
    if [ -f "$final_output_nii" ]; then
      echo "    SKIPPING: Final output already exists at $final_output_nii"
      continue
    fi
    # Step 1: Register PET to T1 
    echo "    Step 1: Registering PET to T1..."
    flirt_cmd="flirt -in \"$pet_scan_path\" -ref \"$t1_brain\" -omat \"$pet_to_t1_mat\" -out \"$pet_to_t1_nii\" -dof 6 -cost normmi"
    echo "      COMMAND: $flirt_cmd"
    eval $flirt_cmd

    if [ ! -f "$pet_to_t1_nii" ]; then
      echo "      ERROR: FLIRT failed for $pet_scan_path. Skipping to next scan."
      continue
    fi

    # Step 2: Warp PET to MNI
    echo "    Step 2: Warping PET to MNI space..."
    applywarp_cmd="applywarp -i \"$pet_to_t1_nii\" -r \"$MNI_STANDARD_BRAIN\" -w \"$warp_field\" -o \"$final_output_nii\""
    echo "      COMMAND: $applywarp_cmd"
    eval $applywarp_cmd

    if [ ! -f "$final_output_nii" ]; then
      echo "      ERROR: applywarp failed for $pet_scan_path."
    else
      echo "    ✅ SUCCESS: Final output created at $final_output_nii"
    fi

    echo ""  # spacing
  done
done

echo "-----------------------------------------------------"
echo "All subjects processed."