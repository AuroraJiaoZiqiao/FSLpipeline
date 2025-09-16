#!/bin/bash

# This script averages SUVR files from different subdirectories.

# Find all AV45 SUVR files
AV45_suvr_files=()
AV45_dirs=$(find . -type d -name "*_AV45")

for dir in $AV45_dirs; do
  files=($(find "$dir" -name "*_MNI_masked.nii.gz"))
  if [ ${#files[@]} -gt 0 ]; then
    AV45_suvr_files+=("${files[@]}")
  fi
done

if [ ${#AV45_suvr_files[@]} -gt 0 ]; then
  # Define output names
  MERGED_TEMP_AV45="AV45_merged_temp.nii.gz"
  OUTPUT_NAME_AV45="AV45_average.nii.gz"

  # Merge all SUVRs into a 4D stack
  echo "Merging into 4D file: $MERGED_TEMP_AV45"
  fslmerge -t "$MERGED_TEMP_AV45" "${AV45_suvr_files[@]}"

  # Compute average across time dimension
  echo "Computing average: $OUTPUT_NAME_AV45"
  fslmaths "$MERGED_TEMP_AV45" -Tmean "$OUTPUT_NAME_AV45"



  echo "AV45 processing complete. Output: $OUTPUT_NAME_AV45"
else
  echo "No AV45 SUVR files found."
fi
