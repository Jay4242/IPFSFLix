#!/bin/bash
confdir="/dev/null/ipfsflix/"   #CHANGE to directory to store the IPFS file list.

#Find all .mp4 & .mkv in the current directory.
mapfile -t movies < <(find $(pwd) \( -iname "*.mp4" -o -iname "*.mkv" \) -print | sort )

#Loop through them and prompt to add to IPFS.
for movie in "${movies[@]}" ; do
  echo "${movie}"
  read -p "Add movie to IPFS? [Y/yes]/[No]: " answer
  if [[ "$answer" =~ [Yy] ]] ; then
    dir=$(basename "$(echo "${movie%.*}")"| sed -e 's/ /./g')  #Create a directory name based on the name of the file.
    if ipfs files ls /movies/ | grep "${dir}" ; then   #If the directory already exists, remove it.
      if [ -n "${dir}" ] ; then  #Test if $dir is not null so we don't wipe out all of /movies/
        ipfs files rm -rf "/movies/${dir}"
      fi
    fi
  #Add the file to IPFS without copying the data into the block store.  Place it in a sub-directory under /movies/.  Log the file to the ipfs-filesystem.list.
  cid=$(ipfs add -w --nocopy --to-files="/movies/${dir}" "${movie}" | tail -n 1 | sed -e 's/.* //g') && echo "${movie}::/movies/${dir}::${cid}::${IPFS_PATH}" >> ${confdir}ipfs-filesystem.list
  fi
done
