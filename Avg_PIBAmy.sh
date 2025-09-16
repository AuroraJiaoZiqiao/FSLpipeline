#!/bin/bash

# This script averages SUVR files from different subdirectories.

# Find all PIB SUVR files
pib_suvr_files=()
pib_dirs=$(find . -type d -name "*_PIB")

for dir in $pib_dirs; do
  files=($(find "$dir" -name "*_MNI_masked.nii.gz"))
  if [ ${#files[@]} -gt 0 ]; then
    pib_suvr_files+=("${files[@]}")
  fi
done

if [ ${#pib_suvr_files[@]} -gt 0 ]; then
  # Define output names
  MERGED_TEMP_PIB="pib_merged_temp.nii.gz"
  OUTPUT_NAME_PIB="pib_average.nii.gz"

  # Merge all SUVRs into a 4D stack
  echo "Merging into 4D file: $MERGED_TEMP_PIB"
  fslmerge -t "$MERGED_TEMP_PIB" "${pib_suvr_files[@]}"

  # Compute average across time dimension
  echo "Computing average: $OUTPUT_NAME_PIB"
  fslmaths "$MERGED_TEMP_PIB" -Tmean "$OUTPUT_NAME_PIB"



  echo "PIB processing complete. Output: $OUTPUT_NAME_PIB"
else
  echo "No PIB SUVR files found."
fi
