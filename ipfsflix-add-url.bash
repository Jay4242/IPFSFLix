#!/bin/bash

# Load configuration file.
load_config() {
  if [ -e ~/.config/ipfsflix.conf ]; then
    source ~/.config/ipfsflix.conf || { echo "Failed to source ~/.config/ipfsflix.conf"; return 1; }
    if [ -z "${confdir}" ]; then
      echo "confdir not set correctly in config file at ~/.config/ipfsflix.conf"
      return 1
    fi
    return 0
  else
    echo "Configuration not found at ~/.config/ipfsflix.conf"
    return 1
  fi
}

# Get directory name from user.
get_directory_name() {
  read -p "Name for wrapping directory: " dir
  echo "${dir}"
}

# Select IPFS path.
select_ipfs_path() {
  local paths_file="$1"
  local selected_path
  local i=0

  echo "Which IPFS_PATH to save under?"
  select path in $(cat "${paths_file}"); do
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

# Add URL to IPFS.
add_url_to_ipfs() {
  local url="$1"
  local bdir="$2"
  local dir_name="$3"
  local confdir="$4"
  local cid

  cid=$(ipfs add -w --nocopy --to-files="/${bdir}/${dir_name}" "${url}" | tail -n 1 | awk -F' ' '{print $2}')
  if [ -z "${cid}" ]; then
    echo "Failed to add URL to IPFS"
    return 1
  fi
  echo "${url}::/${bdir}/${dir_name}::${cid}::${IPFS_PATH}" >> "${confdir}ipfs-filesystem.list" || { echo "Failed to write to ${confdir}ipfs-filesystem.list"; return 1; }
  echo ""
  echo "${cid}"
}

# Main script execution.
main() {
  # Load configuration.
  load_config || exit 1

  # Check if URL is provided.
  if [ -z "$1" ]; then
    echo "Usage: $0 <URL>"
    exit 1
  fi
  local url="$1"

  # Get directory name.
  local dir=$(get_directory_name)
  if [ -z "${dir}" ]; then
    echo "Directory name cannot be empty."
    exit 1
  fi

  # Select IPFS_PATH
  select_ipfs_path "${confdir}ipfs-paths.list" || exit 1

  # Select IPFS MFS directory.
  local bdir=$(select_ipfs_mfs_directory "${dir}")
  if [ -z "${bdir}" ]; then
    exit 1
  fi

  # Add URL to IPFS and update filesystem list.
  add_url_to_ipfs "${url}" "${bdir}" "${dir}" "${confdir}" || exit 1
}

main
