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

# Find movie files.
find_movie_files() {
  local -n movies_array="$1"
  local files
  files=$(find -L "$(pwd)" \( -iname "*.mp4" -o -iname "*.mkv" \) -print | sort)
  movies_array=()
  while IFS= read -r file; do
    movies_array+=("$file")
  done <<< "$files"
}

# Add movie to IPFS.
add_movie_to_ipfs() {
  local movie="$1"
  local confdir="$2"

  echo "${movie}"
  read -p "Add movie to IPFS? [Y/yes]: " answer
  if [[ "$answer" =~ [Yy] ]]; then
    local dir=$(basename "$(echo "${movie%.*}")" | sed -e 's/ /./g')
    if ipfs files ls /movies/ | grep "${dir}"; then
      if [ -n "${dir}" ]; then
        ipfs files rm -rf "/movies/${dir}"
      fi
    fi
    local cid
    cid=$(ipfs add -w --nocopy --to-files="/movies/${dir}" "${movie}" | tail -n 1 | awk -F' ' '{print $2}')
    if [ -z "${cid}" ]; then
      echo "Failed to add $movie to IPFS"
      return 1
    fi
    echo "${movie}::/movies/${dir}::${cid}::${IPFS_PATH}" >> "${confdir}ipfs-filesystem.list"
    if [ $? -ne 0 ]; then
      echo "Failed to write to ${confdir}ipfs-filesystem.list"
      return 1
    fi
  fi
  return 0
}

# Main function
main() {
  # Load configuration.
  if ! load_config; then
    exit 1
  fi

  # Find movie files.
  local movies=()
  find_movie_files movies

  # Loop through each movie and add it to IPFS.
  local num_movies="${#movies[@]}"
  if [[ "$num_movies" -gt 0 ]]; then
    for ((i=0; i<num_movies; i++)); do
      if ! add_movie_to_ipfs "${movies[$i]}" "${confdir}"; then
        echo "Failed to add movie ${movies[$i]}"
      fi
    done
  fi
}

main
