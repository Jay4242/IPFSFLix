#!/bin/bash

# Constants for loop limits
readonly MAX_LINKS=1000
readonly MAX_IPNS=1000

# Load configuration file.
load_config() {
  if [ ! -e ~/.config/ipfsflix.conf ]; then
    echo "Configuration not found at ~/.config/ipfsflix.conf"
    return 1
  fi

  source ~/.config/ipfsflix.conf || { echo "Failed to source ~/.config/ipfsflix.conf"; return 1; }

  if [ -z "${confdir}" ]; then
    echo "confdir not set correctly in config file at ~/.config/ipfsflix.conf"
    return 1
  fi

  if [ -z "${symlinkdir}" ]; then
    echo "symlinkdir not set correctly in config file at ~/.config/ipfsflix.conf"
    return 1
  fi

  if [ -z "${timeout}" ]; then
    echo "timeout not set correctly in config file at ~/.config/ipfsflix.conf"
    return 1
  fi

  return 0
}

# Refresh IPNS symlinks
refresh_ipns_symlinks() {
  local links_file="${symlinkdir}/links.txt"
  local ipns_file="${confdir}/ipfsflix-namemap.list"

  # Change directory to symlinkdir.
  cd "${symlinkdir}" || { echo "Failed to change directory to ${symlinkdir}"; return 1; }

  # Find all symlinks in symlinkdir and store in a file.
  find "${symlinkdir}" -maxdepth 1 -type l -print > "${links_file}" || { echo "Failed to find symlinks in ${symlinkdir}"; return 1; }

  # Read symlinks from the file and remove if not in namemap.list
  local i=0
  while IFS= read -r link; do
    link=$(echo "$link" | sed 's,^\./,,')
    if [ "$i" -gt "$MAX_LINKS" ]; then
      echo "Too many links to process, limit: $MAX_LINKS"
      return 1
    fi
    i=$((i+1))

    # If the symlink does not appear in ${confdir}/ipfsflix-namemap.list, remove it.
    if ! grep -q "${link}" "${confdir}/ipfsflix-namemap.list"; then
      rm "${link}" || echo "Failed to remove symlink: ${link}"
    fi
  done < "${links_file}"

  # Load the ${confdir}/ipfsflix-namemap.list into an array.
  mapfile -t ipns < <(cat "${confdir}/ipfsflix-namemap.list") || { echo "Failed to load ${confdir}/ipfsflix-namemap.list"; return 1; }

  # Loop through each IPNS listing.
  local j=0
  for ipn in "${ipns[@]}"; do
    if [ "$j" -gt "$MAX_IPNS" ]; then
      echo "Too many IPNS entries to process, limit: $MAX_IPNS"
      return 1
    fi
    j=$((j+1))

    # Load the proper IPFS_PATH
    export IPFS_PATH=$(echo "${ipn}" | awk -F'::' '{print $4}')
    if [ -z "${IPFS_PATH}" ]; then
      echo "IPFS_PATH not found in IPNS entry: ${ipn}"
      continue
    fi

    # Find the name of the symlink.
    local vname=$(echo "${ipn}" | awk -F'::' '{print $2 }')
    if [ -z "${vname}" ]; then
      echo "Symlink name not found in IPNS entry: ${ipn}"
      continue
    fi

    # Resolve the IPNS address to an IPFS address and save the CID to cid.
    local cid=$(ipfs name resolve --dhtt "${timeout}s" $(echo ${ipn} | awk -F'::' '{print $3}'))
    if [ -z "${cid}" ]; then
      echo "Failed to resolve IPNS address for ${vname}"
      continue
    fi

    # Create the proper relative path for the new IPFS address. Add the CID to the end.
    local mcid=$(echo -n "$(echo ${ipn} | awk -F'::' '{print $1}')${cid}")

    # Check if the symlink already exists.
    if [[ -L "${vname}" ]]; then
      # If it does, read it to test it against the new CID.
      local ecid=$(readlink "${vname}")

      # Test the existing CID against the new CID.
      if [[ "${ecid}" == "${mcid}" ]]; then
        # If the CIDs were already the same, continue to the next IPNS pairing row.
        continue
      fi
    fi

    # Use the CID modified with the relative path to create the symlink.
    ln -sf "${mcid}" "${vname}" || { echo "Failed to create symlink ${vname} -> ${mcid}"; continue; }

    # Traverse the symlink with tree to load the directory structure and filenames into the local IPFS.
    timeout ${timeout}s tree "${vname}" > /dev/null
  done

  rm "${links_file}"
  return 0
}

# Main script execution.
main() {
  # Load configuration.
  if ! load_config; then
    exit 1
  fi

  # Refresh IPNS symlinks
  if ! refresh_ipns_symlinks; then
    exit 1
  fi

  exit 0
}

main
