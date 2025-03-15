#!/bin/bash

# Constants
readonly MAX_MATCHES=100

# Load configuration.
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
  return 0
}

# Display match information.
display_match_info() {
  local match="$1"
  echo "${match}" | awk -F'::' '{print "Location on disk:\t" $1 "\nMFS Location:\t\t" $2 "\nIPFS CID:\t\t" $3 "\nIPFS_PATH:\t\t" $4 }'
}

# Remove match from IPFS.
remove_match() {
  local match="$1"

  # Export IPFS_PATH
  export IPFS_PATH=$(echo "${match}" | awk -F'::' '{print $4 }')
  if [ -z "${IPFS_PATH}" ]; then
    echo "IPFS_PATH not found in match: ${match}"
    return 1
  fi

  # Remove match from IPFS MFS.
  ipfs files rm -rf $(echo "${match}" | awk -F'::' '{print $2 }')
  if [ $? -ne 0 ]; then
    echo "Failed to remove from IPFS MFS"
    return 1
  fi

  # Remove match from IPFS pin.
  ipfs pin rm -r $(echo "${match}" | awk -F'::' '{print $3 }')
  if [ $? -ne 0 ]; then
    echo "Failed to remove from IPFS pin"
    return 1
  fi

  return 0
}

# Remove match from filesystem list.
remove_match_from_list() {
  local match="$1"
  sed -i "\|^${match}|d" "${confdir}ipfsflix-filesystem.list"
  if [ $? -ne 0 ]; then
    echo "Failed to remove matching line from ${confdir}ipfsflix-filesystem.list"
    return 1
  fi
  return 0
}

# Process a single match.
process_match() {
  local match="$1"

  # Display match information.
  display_match_info "${match}"

  # Prompt for deletion.
  read -p "Remove from IPFSFlix? [y/N]: " answer

  # If Y/y(es) is chosen.
  case "$answer" in
    [Yy]*)
      if ! remove_match "${match}"; then
        echo "Failed to remove match"
        return 1
      fi

      if ! remove_match_from_list "${match}"; then
        echo "Failed to remove match from list"
        return 1
      fi
      ;;
    *)
      echo "Skipping removal."
      return 0
      ;;
  esac

  return 0
}

# Main script execution.
main() {
  # Load configuration.
  if ! load_config; then
    exit 1
  fi

  # Store parameters as the search phrase.
  local search_phrase="$*"

  # Search the file log for the file.
  mapfile -t possible_matches < <(grep -i "${search_phrase}" "${confdir}ipfsflix-filesystem.list")

  # Loop through matching lines.
  local num_matches="${#possible_matches[@]}"
  if [ "$num_matches" -gt "$MAX_MATCHES" ]; then
    echo "Too many matches, limit: $MAX_MATCHES"
    exit 1
  fi

  local i=0
  for match in "${possible_matches[@]}"; do
    if [ "$i" -ge "$MAX_MATCHES" ]; then
      echo "Reached maximum number of matches to process: $MAX_MATCHES"
      break
    fi

    if ! process_match "${match}"; then
      echo "Failed to process match: ${match}"
    fi

    i=$((i+1))
  done
  exit 0
}

main
