#!/bin/bash
let plexserv=0
let jellyserv=0
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

if sudo service plexmediaserver status | grep -i "(running)"
then
   let plexserv=1
   sudo service plexmediaserver stop
fi

if sudo service jellyfin status | grep -i "(running)"
then
   let jellyserv=1
   sudo service jellyfin stop
fi

#Unmount IPFS/IPNS mounts.  IPNS cannot be published while mounted.
mapfile -t mounts < <(mount | grep -i -e "/ipfs" -e "/ipns" | awk -F' ' '{print $3}')
for mount in "${mounts[@]}" ; do
  sudo umount "${mount}"
done

#Store the paths in an array.
mapfile -t paths < <(cat ${confdir}/ipfsflix-paths.list)

#Loop through the paths.
for path in "${paths[@]}" ; do

  #Export the path.
  export IPFS_PATH="${path}"
  #Store the path keys in an array.
  mapfile -t keys < <(ipfs key list)

  #Loop through the keys and check if there's a corresponding root directory.
  for key in "${keys[@]}" ; do

    #If the key matches a base directory.
    if ipfs files ls | grep -i -q "${key}" ; then
      ipfs name publish --key="${key}" "$(ipfs files stat --hash /${key})"
    fi
  done
done

#Refresh local symlinks to IPFS addresses.
ipfsflix-ipns-refresh.bash


#Re-mount the IPFS/IPNS mounts.
mapfile -t paths < <(cat ${confdir}ipfsflix-paths.list)
for path in "${paths[@]}" ; do
  export IPFS_PATH=${path}
  ipfs mount
done

#Restart Plex if it was running.
if [[ "${plexserv}" == "1" ]]
then
   sudo service plexmediaserver start
fi

#Restart Jellyfin if it was running.
if [[ "${jellyserv}" == "1" ]]
then
   sudo service jellyfin start
fi
