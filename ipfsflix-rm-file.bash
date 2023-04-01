#!/bin/bash
## ipfsflix-rm-file.bash
## To search the ipfsflix-filesystem.list and remove any corresponding matches from the IPFS MFS, IPFS pins, and finally the ipfs-filesystem.list.

#Load configuration.
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

#Store parameters as the search phrase.
search_phrase="$*"

#Search the file log for the file.
mapfile -t possible_matches < <(grep -i "${search_phrase}" ${confdir}ipfsflix-filesystem.list)

#Loop through matching lines.
for match in "${possible_matches}" ; do

  #Display match information.
  echo "${match}" | awk -F'::' '{print "Location on disk:\t" $1 "\nMFS Location:\t\t" $2 "\nIPFS CID:\t\t" $3 "\nIPFS_PATH:\t\t" $4 }'

  #Prompt for deletion.
  read -p "Remove from IPFSFlix? [y/N]: " answer

  #If Y/y(es) is chosen.
  if [[ "$answer" =~ [Yy] ]] ; then

    #Export IPFS_PATH
    export IPFS_PATH=$(echo "${match}" | awk -F'::' '{print $4 }') || exit 1

    #Remove match from IPFS MFS.
    ipfs files rm -rf $(echo "${match}" | awk -F'::' '{print $2 }') || exit 1

    #Remove match from IPFS pin.
    ipfs pin rm -r $(echo "${match}" | awk -F'::' '{print $3 }') || exit 1

    #Remove match from ipfs-filesystem.list.
    sed -i "\|^${match}|d" ${confdir}ipfsflix-filesystem.list || echo "Failed to remove maching line from ${confdir}ipfsflix-filesystem.list"
  fi
done
