#!/bin/bash

# Constants for loop limits
readonly MAX_MOUNTS=100
readonly MAX_PATHS=100
readonly MAX_KEYS=100

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
  return 0
}

# Stop Plex Media Server
stop_plex() {
  if sudo service plexmediaserver status | grep -q "(running)"; then
    if ! sudo service plexmediaserver stop; then
      echo "Failed to stop Plex Media Server"
      return 1
    fi
    echo "Plex Media Server stopped."
    return 0
  else
    echo "Plex Media Server is not running."
    return 0
  fi
}

# Stop Jellyfin
stop_jellyfin() {
  if sudo service jellyfin status | grep -q "(running)"; then
    if ! sudo service jellyfin stop; then
      echo "Failed to stop Jellyfin"
      return 1
    fi
    echo "Jellyfin stopped."
    return 0
  else
    echo "Jellyfin is not running."
    return 0
  fi
}

# Unmount IPFS/IPNS mounts
unmount_ipfs() {
  local mounts
  mounts=$(mount | grep -i -e "/ipfs" -e "/ipns" | awk -F' ' '{print $3}')
  local IFS=$'\n'
  local mount_array=($(echo "${mounts}"))
  unset IFS

  local num_mounts="${#mount_array[@]}"
  if [[ "$num_mounts" -gt "$MAX_MOUNTS" ]]; then
    echo "Too many mounts to process, limit: $MAX_MOUNTS"
    return 1
  fi

  local i=0
  for mount in "${mount_array[@]}"; do
    if ! sudo umount "${mount}"; then
      echo "Failed to unmount ${mount}"
      return 1
    fi
    i=$((i+1))
  done
  return 0
}

# Publish IPFS names
publish_ipfs_names() {
  local paths_file="${confdir}ipfsflix-paths.list"
  local paths
  paths=$(cat "${paths_file}")
  local IFS=$'\n'
  local paths_array=($(echo "${paths}"))
  unset IFS

  local num_paths="${#paths_array[@]}"
  if [[ "$num_paths" -gt "$MAX_PATHS" ]]; then
    echo "Too many paths to process, limit: $MAX_PATHS"
    return 1
  fi

  local i=0
  for path in "${paths_array[@]}"; do
    export IPFS_PATH="${path}"
    local keys
    keys=$(ipfs key list)
    local IFS=$'\n'
    local keys_array=($(echo "${keys}"))
    unset IFS

    local num_keys="${#keys_array[@]}"
    if [[ "$num_keys" -gt "$MAX_KEYS" ]]; then
      echo "Too many keys to process, limit: $MAX_KEYS"
      return 1
    fi

    local j=0
    for key in "${keys_array[@]}"; do
      if ipfs files ls | grep -q -i "${key}"; then
        local hash=$(ipfs files stat --hash "/${key}")
        if [ -z "${hash}" ]; then
          echo "Failed to get hash for /${key}"
          return 1
        fi
        if ! ipfs name publish --key="${key}" "${hash}"; then
          echo "Failed to publish IPNS name for key ${key}"
          return 1
        fi
      fi
      j=$((j+1))
    done
    i=$((i+1))
  done
  return 0
}

# Remount IPFS
remount_ipfs() {
  local paths_file="${confdir}ipfsflix-paths.list"
  local paths
  paths=$(cat "${paths_file}")
  local IFS=$'\n'
  local paths_array=($(echo "${paths}"))
  unset IFS

  local i=0
  for path in "${paths_array[@]}"; do
    export IPFS_PATH="${path}"
    if ! ipfs mount; then
      echo "Failed to mount IPFS at ${path}"
      return 1
    fi
    i=$((i+1))
  done
  return 0
}

# Start Plex Media Server
start_plex() {
  if ! sudo service plexmediaserver start; then
    echo "Failed to start Plex Media Server"
    return 1
  fi
  echo "Plex Media Server started."
  return 0
}

# Start Jellyfin
start_jellyfin() {
  if ! sudo service jellyfin start; then
    echo "Failed to start Jellyfin"
    return 1
  fi
  echo "Jellyfin started."
  return 0
}

# Main script execution.
main() {
  local plexserv=0
  local jellyserv=0

  # Load configuration.
  if ! load_config; then
    exit 1
  fi

  # Stop Plex if running
  if sudo service plexmediaserver status | grep -q "(running)"; then
    plexserv=1
    if ! stop_plex; then
      exit 1
    fi
  fi

  # Stop Jellyfin if running
  if sudo service jellyfin status | grep -q "(running)"; then
    jellyserv=1
    if ! stop_jellyfin; then
      exit 1
    fi
  fi

  # Unmount IPFS/IPNS mounts.  IPNS cannot be published while mounted.
  if ! unmount_ipfs; then
    exit 1
  fi

  # Publish IPFS names
  if ! publish_ipfs_names; then
    exit 1
  fi

  # Refresh local symlinks to IPFS addresses.
  ipfsflix-ipns-refresh.bash

  # Re-mount the IPFS/IPNS mounts.
  if ! remount_ipfs; then
    exit 1
  fi

  # Restart Plex if it was running.
  if [[ "${plexserv}" == "1" ]]; then
    if ! start_plex; then
      exit 1
    fi
  fi

  # Restart Jellyfin if it was running.
  if [[ "${jellyserv}" == "1" ]]; then
    if ! start_jellyfin; then
      exit 1
    fi
  fi

  exit 0
}

main
