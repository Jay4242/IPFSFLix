#!/bin/bash
let plexserv=0
let jellyserv=0

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

sudo umount /ipfs
sudo umount /ipns
ipfs name publish --key=movies "$(ipfs files stat --hash /movies)"
ipfs mount
ipns-refresh.bash
if [[ "${plexserv}" == "1" ]]
then
   sudo service plexmediaserver start
fi

if [[ "${jellyserv}" == "1" ]]
then
   sudo service jellyfin start
fi
