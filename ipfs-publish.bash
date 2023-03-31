#!/bin/bash
let plexserv=0
let jellyserv=0
symlinkdir="/dev/null/"

#If plex is running, remember that and stop plex.  (prevents using a file/directory while we change things)
if sudo service plexmediaserver status | grep -i "(running)"
then
   let plexserv=1
   sudo service plexmediaserver stop
fi

#If jellyfin is running, remember that and stop Jellyfin.  (prevents using a file/directory while we change things)
if sudo service jellyfin status | grep -i "(running)"
then
   let jellyserv=1
   sudo service jellyfin stop
fi

#Unmount IPFS/IPNS mounts.
mapfile -t mounts < <(mount | grep -i -e "/ipfs" -e "/ipns" | awk -F' ' '{print $3}')
for mount in "${mounts[@]}" ; do
  sudo umount "${mount}"
done

#Publish the new 'movies' directory.
ipfs name publish --key=movies "$(ipfs files stat --hash /movies)"

#Re-mount the IPFS/IPNS mounts.
mapfile -t paths < <(cat ${symlinkdir}ipfs-namemap.txt | awk -F'::' '{print $4}' | sort -u)
for path in "${paths[@]}" ; do
  export IPFS_PATH=${path}
  ipfs mount
done

#Refresh local symlinks to IPFS addresses.
ipns-refresh.bash

#If plex was running before, start it again.
if [[ "${plexserv}" == "1" ]]
then
   sudo service plexmediaserver start
fi

#If jellyfin was running before, start it again.
if [[ "${jellyserv}" == "1" ]]
then
   sudo service jellyfin start
fi
