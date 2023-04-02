#!/bin/bash

#Load configuration file.
if [ -e ~/.config/ipfsflix.conf ] ; then
  source ~/.config/ipfsflix.conf || exit 1
  if [ -z "${confdir}" ] ; then
    echo "confdir not set correctly in config file at ~/.config/ipfsflix.conf"
    exit 1
  fi
  if [ -z "${symlinkdir}" ] ; then
    echo "symlinkdir not set correctly in config file at ~/.config/ipfsflix.conf"
    exit 1
  fi
  if [ -z "${timeout}" ] ; then
    echo "timeout not set correctly in config file at ~/.config/ipfsflix.conf"
    exit 1
  fi
else
  echo "Configuration not found at ~/.config/ipfsflix.conf"
  exit 1
fi

#cd to symlinkdir.
cd "${symlinkdir}" || exit 1

#Find all symlinks in symlinkdir.
mapfile -t links < <(find "${symlinkdir}" -maxdepth 1 -type l | sed 's,^\./,,')

#Loop through each symlink.
for link in "${links[@]}" ; do

  #If the symlink does not appear in ${confdir}/ipfsflix-namemap.list, remove it.
  grep -q "${link}" "${confdir}/ipfsflix-namemap.list" || rm "${link}"
done

#Load the ${confdir}/ipfsflix-namemap.list into an array.
mapfile -t ipns < <(cat "${confdir}/ipfsflix-namemap.list") || exit 1

#Loop through each IPNS listing.
for ipn in "${ipns[@]}" ; do

  #Load the proper IPFS_PATH
  export IPFS_PATH=$(echo "${ipn}" | awk -F'::' '{print $4}')

  #Find the name of the symlink.
  vname=$(echo "${ipn}" | awk -F'::' '{print $2 }')

  #Resolve the IPNS address to an IPFS address and save the CID to cid.
  cid=$(ipfs name resolve --dhtt "${timeout}s" $(echo ${ipn} | awk -F'::' '{print $3}')) || continue

  #Create the proper relative path for the new IPFS address.  Add the CID to the end.
  mcid=$(echo -n "$(echo ${ipn} | awk -F'::' '{print $1}')${cid}")

  #Check if the symlink already exists.
  if [[ -L "${vname}" ]] ; then

    #If it does, read it to test it against the new CID.
    ecid=$(readlink "${vname}")

    #Test the existing CID against the new CID.
    if [[ "${ecid}" == "${mcid}" ]] ; then

      #If the CIDs were already the same, continue to the next IPNS pairing row.
      continue
    fi
  fi

  #Use the CID modified with the relative path to create the symlink.
  ln -sf "${mcid}" "${vname}" || continue

  #Traverse the symlink with tree to load the directory structure and filenames into the local IPFS.
  timeout ${timeout}s tree "${vname}" > /dev/null
done
