#!/bin/bash

# Constants for loop limits
readonly MAX_PATHS=1000
readonly MAX_DIRS=1000
readonly MAX_ROWS=1000
readonly MAX_LAYERS=20

# Load configuration file.
load_config() {
  if [ ! -e ~/.config/ipfsflix.conf ]; then
    echo "Configuration not found at ~/.config/ipfsflix.conf"
    return 1
  fi

  source ~/.config/ipfsflix.conf || { echo "~/.config/ipfsflix.conf not sourced correctly"; return 1; }

  if [ -z "${confdir}" ]; then
    echo "confdir not set correctly in config file at ~/.config/ipfsflix.conf"
    return 1
  fi

  return 0
}

# Check if a directory exists in IPFS MFS
ipfs_dir_exists() {
  local dirpath="$1"
  if ! ipfs files stat "${dirpath}" &>/dev/null; then
    return 1
  else
    return 0
  fi
}

# Create directory in IPFS MFS if it doesn't exist
ipfs_mkdir_if_not_exists() {
  local dirpath="$1"
  if ! ipfs_dir_exists "${dirpath}"; then
    ipfs files mkdir "${dirpath}"
    if [ $? -ne 0 ]; then
      echo "Failed to create directory ${dirpath}"
      return 1
    fi
  fi
  return 0
}

# Remap CID to MFS location
ipfs_remap_cid_to_mfs() {
  local cid="$1"
  local mfs="$2"

  ipfs files cp "/ipfs/${cid}" "${mfs}"
  if [ $? -ne 0 ]; then
    echo "Failed to copy /ipfs/${cid} to ${mfs}"
    return 1
  fi
  return 0
}

# Process a single row from the filesystem list
process_filesystem_row() {
  local row="$1"

  local mfs=$(echo "${row}" | awk -F'::' '{print $2}')
  local cid=$(echo "${row}" | awk -F'::' '{print $3}')

  # Check if mfs and cid are empty
  if [ -z "${mfs}" ] || [ -z "${cid}" ]; then
    echo "Error: MFS or CID is empty in row: ${row}"
    return 1
  fi

  # Create directory structure if it doesn't exist
  local dirpath=""
  local i=0
  local IFS=$'\n'
  local layers=($(echo "${mfs%/*}" | sed -e 's/\//\n/g' | grep -v "^$"))
  unset IFS

  if [ ${#layers[@]} -gt "$MAX_LAYERS" ]; then
    echo "Too many layers in path, limit: $MAX_LAYERS"
    return 1
  fi

  for layer in "${layers[@]}"; do
    dirpath="${dirpath}/${layer}"
    if ! ipfs_mkdir_if_not_exists "${dirpath}"; then
      echo "Failed to create directory structure for ${mfs}"
      return 1
    fi
    i=$((i+1))
  done

  # Remap the CID to the MFS location
  if ! ipfs_remap_cid_to_mfs "${cid}" "${mfs}"; then
    echo "Failed to remap CID ${cid} to ${mfs}"
    return 1
  fi

  return 0
}

# Process a directory and path combination
process_directory_path() {
  local path="$1"
  local dir="$2"
  local i=0

  # Get all corresponding lines
  local rows
  rows=$(cat "${confdir}/ipfsflix-filesystem.list" | grep -i "${path}" | grep -i "${dir}")
  if [ -z "${rows}" ]; then
    echo "No matching rows found for path ${path} and dir ${dir}"
    return 0
  fi

  local IFS=$'\n'
  local rows_array=($(echo "${rows}"))
  unset IFS

  if [ ${#rows_array[@]} -gt "$MAX_ROWS" ]; then
    echo "Too many rows to process, limit: $MAX_ROWS"
    return 1
  fi

  # Loop through each row that matched
  for row in "${rows_array[@]}"; do
    if ! process_filesystem_row "${row}"; then
      echo "Failed to process row: ${row}"
      return 1
    fi
    i=$((i+1))
  done

  return 0
}

# Main function
main() {
  # Load configuration
  if ! load_config; then
    exit 1
  fi

  # Get all IPFS_PATHs
  local paths
  paths=$(cat "${confdir}/ipfsflix-paths.list")
  if [ -z "${paths}" ]; then
    echo "No paths found in ${confdir}/ipfsflix-paths.list"
    exit 1
  fi

  local IFS=$'\n'
  local paths_array=($(echo "${paths}"))
  unset IFS

  if [ ${#paths_array[@]} -gt "$MAX_PATHS" ]; then
    echo "Too many paths to process, limit: $MAX_PATHS"
    exit 1
  fi

  # Loop through each IPFS_PATH
  local i=0
  for path in "${paths_array[@]}"; do
    # Export the IPFS_PATH
    export IPFS_PATH="${path}"

    # Get all base directories
    local dirs
    dirs=$(ipfs files ls)
    if [ -z "${dirs}" ]; then
      echo "No directories found in IPFS files ls"
      continue
    fi

    local IFS=$'\n'
    local dirs_array=($(echo "${dirs}"))
    unset IFS

    if [ ${#dirs_array[@]} -gt "$MAX_DIRS" ]; then
      echo "Too many directories to process, limit: $MAX_DIRS"
      exit 1
    fi

    # Loop through each directory
    local j=0
    for dir in "${dirs_array[@]}"; do
      # For each directory & path, process all corresponding rows
      if ! process_directory_path "${path}" "${dir}"; then
        echo "Failed to process directory ${dir} and path ${path}"
        exit 1
      fi
      j=$((j+1))
    done
    i=$((i+1))
  done

  exit 0
}

main
