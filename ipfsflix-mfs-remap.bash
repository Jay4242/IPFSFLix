#!/bin/bash

#Load configuration file.
if [ -e ~/.config/ipfsflix.conf ] ; then
  source ~/.config/ipfsflix.conf || echo "~/.config/ipfsflix.conf not sourced correctly"
  if [ -z "${confdir}" ] ; then
    echo "confdir not set correctly in config file at ~/.config/ipfsflix.conf"
    exit 1
  fi
else
  echo "Configuration not found at ~/.config/ipfsflix.conf"
  exit 1
fi

#Get all IPFS_PATHs
mapfile -t paths < <(cat ${confdir}/ipfsflix-paths.list)

#Loop through each IPFS_PATH
for path in "${paths[@]}" ; do

  #Export the IPFS_PATH
  export IPFS_PATH="${path}"

  #Get all base directories.
  mapfile -t dirs < <(ipfs files ls)

  #Loop through each directory.
  for dir in "${dirs[@]}" ; do

    #For each directory & path, get all corresponding lines.
    mapfile -t rows < <(cat ${confdir}/ipfsflix-filesystem.list | grep -i "${path}" | grep -i "${dir}" )

    #Loop through each row that matched.
    for row in "${rows[@]}" ; do

      #Get the IPFS MFS Location.
      mfs=$(echo "${row}" | awk -F'::' '{print $2}')

      #Get the CID of the file we inserted to IPFSFLix.
      cid=$(echo "${row}" | awk -F'::' '{print $3}')

      #Check if directory structure exists.
      unset dirpath
      mapfile -t layers < <(echo "${mfs%/*}" | sed -e 's/\//\n/g' | grep -v "^$")
      for layer in "${layers[@]}" ; do

        dirpath="${dirpath}/${layer}"
        if ! ipfs files stat "${dirpath}" &>/dev/null ; then
           ipfs files mkdir "${dirpath}"
        fi

      done

      #Remap the ${cid} to the ${mfs} location.
      ipfs files cp "/ipfs/${cid}" "${mfs}"

    done  #Row is done.

  done  #Directory is done.

done  #Path is done.
