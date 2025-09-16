#!/bin/bash

# This script averages SUVR files from all tau subdirectories.

# Find all tau SUVR files
tau_suvr_files=()
tau_dirs=$(find . -type d -name "tau")

for dir in $tau_dirs; do
  files=($(find "$dir" -name "*_masked.nii.gz"))
  if [ ${#files[@]} -gt 0 ]; then
    tau_suvr_files+=("${files[@]}")
  fi
done

if [ ${#tau_suvr_files[@]} -gt 0 ]; then
  # Define output names
  MERGED_TEMP_TAU="tau_merged_temp.nii.gz"
  OUTPUT_NAME_TAU="tau_average.nii.gz"

  # Merge all SUVRs into a 4D stack
  echo "Merging into 4D file: $MERGED_TEMP_TAU"
  fslmerge -t "$MERGED_TEMP_TAU" "${tau_suvr_files[@]}"

  # Compute average across time dimension
  echo "Computing average: $OUTPUT_NAME_TAU"
  fslmaths "$MERGED_TEMP_TAU" -Tmean "$OUTPUT_NAME_TAU"


  echo "Tau processing complete. Output: $OUTPUT_NAME_TAU"
else
  echo "No tau SUVR files found."
fi
