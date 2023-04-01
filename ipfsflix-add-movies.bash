#!/bin/bash
if [ -e ~/.config/ipfsflix.conf ] ; then
  source ~/.config/ipfsflix.conf || exit 1
  if [ -z "${confdir}" ] ; then
    echo "confdir not set correctly in config file at ~/.config/ipfsflix.conf"
    exit 1
  fi
else
  echo "Configuration not found at ~/.config/ipfsflix.conf"
  exit 1
fi
mapfile -t movies < <(find -L $(pwd) \( -iname "*.mp4" -o -iname "*.mkv" \) -print | sort )

for movie in "${movies[@]}" ; do
  echo "${movie}"
  read -p "Add movie to IPFS? [Y/yes]: " answer
  if [[ "$answer" =~ [Yy] ]] ; then
    dir=$(basename "$(echo "${movie%.*}")"| sed -e 's/ /./g')
    if ipfs files ls /movies/ | grep "${dir}" ; then
      if [ -n "${dir}" ] ; then
        ipfs files rm -rf "/movies/${dir}"
      fi
    fi
  cid=$(ipfs add -w --nocopy --to-files="/movies/${dir}" "${movie}" | tail -n 1 | awk -F' ' '{print $2}') && echo "${movie}::/movies/${dir}::${cid}::${IPFS_PATH}" >> ${confdir}ipfs-filesystem.list
  fi
done
