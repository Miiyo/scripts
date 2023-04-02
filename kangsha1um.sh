#!/bin/bash

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <base_directory> <file_path>"
  echo "    <base_directory>: The base directory where the files listed in the input file can be found"
  echo "    <file_path>: The path to the input file containing the list of files to generate SHA1 hashes for"
  exit 1
fi

# Get the base directory from the command line argument
base_dir="$1"

# Get the file path from the command line argument
file_path="$2"

# Extract the file name from the file path
file_name=$(basename "$file_path")

# Check that the base directory exists
if [ ! -d "$base_dir" ]; then
  echo "Error: Base directory '$base_dir' not found"
  exit 1
fi

# Check that the input file exists
if [ ! -f "$file_path" ]; then
  echo "Error: File '$file_path' not found"
  exit 1
fi

# Create the output file name
output_file="${file_name%.*}_SHA1.txt"

# Check if the output file exists and remove it if it does
if [ -f "$output_file" ]; then
  rm "$output_file"
fi

# Print the base directory, file path, and timestamp to the output file
echo "# Base directory: $base_dir" >> "$output_file"
echo "# Input file: $file_path" >> "$output_file"
echo "# Timestamp: $(date)" >> "$output_file"

# Loop through each line in the file
while IFS= read -r line; do
  # Get the full file path from the base directory and the current line
  file="$base_dir/$line"
  # Check that the file exists
  if [ ! -f "$file" ]; then
    echo "[File not found $file]" >> "$output_file"
    continue
  fi
  # Generate the SHA1 hash for the current file
  hash=$(sha1sum "$file" | awk '{print $1}')
  # Remove the base directory from the file path
  file_path=${file/$base_dir\//}
  # Output the file path and its hash to the output file
  echo "${file_path} | ${hash}" >> "$output_file"
done < "$file_path"

echo "Done. Results saved to '$output_file'."
