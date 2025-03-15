#!/bin/bash

# Load configuration file.
load_config() {
  if [ -e ~/.config/ipfsflix.conf ]; then
    source ~/.config/ipfsflix.conf || { echo "Failed to source ~/.config/ipfsflix.conf"; exit 1; }
    if [ -z "${confdir}" ]; then
      echo "confdir not set correctly in config file at ~/.config/ipfsflix.conf"
      exit 1
    fi
  else
    echo "Configuration not found at ~/.config/ipfsflix.conf"
    exit 1
  fi
}

# Find file.
find_file() {
  local search_path="$1"
  local found_file
  # Use a loop with a fixed depth to avoid unbounded recursion
  find -L "${search_path}" -maxdepth 1 -print -quit | while read -r file; do
    found_file="${file}"
    break
  done
  echo "${found_file}"
}

# Select IPFS path.
select_ipfs_path() {
  local paths_file="$1"
  local selected_path
  local i=0
  local path_array
  
  # Read paths into an array
  mapfile -t path_array < "${paths_file}"
  
  # Check if the file is empty
  if [ ${#path_array[@]} -eq 0 ]; then
    echo "No paths found in ${paths_file}"
    return 1
  fi

  echo "Which IPFS_PATH to save under?"
  select path in "${path_array[@]}"; do
    if [ -n "${path}" ]; then
      export IPFS_PATH="${path}"
      selected_path="${path}"
      break
    else
      echo "Invalid selection."
    fi
    
    # Limit the number of attempts
    i=$((i+1))
    if [ "$i" -gt 5 ]; then
      echo "Too many invalid attempts."
      return 1
    fi
  done
  echo "${selected_path}"
}

# Get directory name.
get_directory_name() {
  local file="$1"
  if [ -d "${file}" ]; then
    echo "$(basename "${file}")"
  else
    echo "$(basename "$(echo "${file%.*}")")"
  fi
}

# Select IPFS MFS directory.
select_ipfs_mfs_directory() {
  local dir_name="$1"
  local selected_bdir
  local i=0

  echo "Which IPFS MFS Directory to save under?"
  select bdir in $(ipfs files ls); do
    if [ -n "${bdir}" ]; then
      # Check if exact directory already exists, remove it.
      ipfs files ls "/${bdir}/" | while read -r existing_dir; do
        if [ "${existing_dir}" = "${dir_name}" ]; then
          # Make sure ${dir_name} isnt null somehow so we dont wipe out the entire base directory.
          if [ -n "${dir_name}" ]; then
            ipfs files rm -rf "/${bdir}/${dir_name}"
          fi
          break
        fi
      done
      selected_bdir="${bdir}"
      break
    else
      echo "Invalid selection."
    fi
    
    # Limit the number of attempts
    i=$((i+1))
    if [ "$i" -gt 5 ]; then
      echo "Too many invalid attempts."
      return 1
    fi
  done
  echo "${selected_bdir}"
}

# Add file to IPFS.
add_file_to_ipfs() {
  local file="$1"
  local bdir="$2"
  local dir_name="$3"
  local confdir="$4"
  local cid
  
  #If the file is a directory, add it with IPFS recursively and ignore problematic files like txt, nfo, rar.
  if [ -d "${file}" ] ; then
    cid=$(ipfs add --ignore="*.txt" --ignore="*.nfo" --ignore="*.rar" --ignore="*.exe" -r --nocopy --to-files="/${bdir}/${dir_name}" "${file}" | tail -n 1 | awk -F' ' '{print $2}')
    if [ -z "${cid}" ]; then
      echo "Failed to add directory to IPFS"
      return 1
    fi
    echo "${file}::/${bdir}/${dir_name}::${cid}::${IPFS_PATH}" >> "${confdir}ipfs-filesystem.list" || { echo "Failed to write to ${confdir}ipfs-filesystem.list"; return 1; }
  else
    #If adding the file is successful pipe the metadata into ${confdir}ipfs-filesystem.list
    cid=$(ipfs add -w --nocopy --to-files="/${bdir}/${dir_name}" "${file}" | tail -n 1 | awk -F' ' '{print $2}')
    if [ -z "${cid}" ]; then
      echo "Failed to add file to IPFS"
      return 1
    fi
    echo "${file}::/${bdir}/${dir_name}::${cid}::${IPFS_PATH}" >> "${confdir}ipfs-filesystem.list" || { echo "Failed to write to ${confdir}ipfs-filesystem.list"; return 1; }
  fi
  echo "${cid}"
}

# Main script execution.
main() {
  # Load configuration.
  load_config || exit 1

  # Set file to script arguments, exit if the file can't be found.
  local file
  file=$(find_file "$(pwd)/$*")
  if [ -z "${file}" ]; then
    echo "File not found."
    exit 1
  fi

  # Echo the file so the user can visually confirm.
  echo "${file}"

  # Select IPFS_PATH
  select_ipfs_path "${confdir}ipfs-paths.list" || exit 1
  
  # Set virtual directory name
  local dir=$(get_directory_name "${file}")

  # Select IPFS MFS directory.
  local bdir=$(select_ipfs_mfs_directory "${dir}")
  if [ -z "${bdir}" ]; then
    exit 1
  fi

  # Add file to IPFS and update filesystem list.
  add_file_to_ipfs "${file}" "${bdir}" "${dir}" "${confdir}" || exit 1
}

main
