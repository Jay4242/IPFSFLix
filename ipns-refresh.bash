#!/bin/bash
namemap="ipfs-namemap.list"             #Text file with relative/path::symlink-name::/ipns/address::IPFS_PATH for each IPNS address to resolve & symlink.
basedir="/dev/null/ipfs-media/"        #CHANGE THIS.  Base directory the symlinks will be located at, along with the above namemap.
timeout="30"                           #Timeout for both IPNS resolve & 'tree' of the files & directories to fetch the structure.  Both can potentially take a long time.

#cd to symlink base directory.
cd "${basedir}" || exit 1

#find any existing symlinks.
mapfile -t links < <(find . -maxdepth 1 -type l | sed 's,^\./,,')

#Check if symlinks exist in our list, remove them if they aren't.
for link in "${links[@]}" ; do
  grep -q "${link}" "${namemap}" || rm "${link}"
done

#Get IPNS symlink list.
mapfile -t ipns < <(cat "${namemap}") || exit 1

#Loop through IPNS symlink list.
for ipn in "${ipns[@]}" ; do
  export IPFS_PATH=$(echo "${ipn}" | awk -F'::' '{print $4}')  #Export correct IPFS_PATH
  vname=$(echo "${ipn}" | awk -F'::' '{print $2 }')  #Find symlink name.
  cid=$(ipfs name resolve --dhtt "${timeout}s" $(echo ${ipn} | awk -F'::' '{print $3}')) || echo "Failed to resolve for ${vname}" && continue  #Resolve the IPNS address to an IPFS address.  Move on if it takes longer than $timeout.
  mcid=$(echo -n "$(echo ${ipn} | awk -F'::' '{print $1}')${cid}")  #Construct the symlink CID location.
  if [[ -L "${vname}" ]] ; then  #If the symlink already exists check if it changed, if not we can skip it.
    ecid=$(readlink "${vname}")
    if [[ "${ecid}" == "${mcid}" ]] ; then
      continue
    fi
  fi
  ln -sf "${mcid}" "${vname}" || echo "Failed to make symlink ${vname} to ${mcid}" && exit 1  #Create or update the symlink with the new IPFS address.
  timeout ${timeout}s tree "${vname}" > /dev/null  #Traverse the new IPFS directory with 'tree' to cache the file info.
done
