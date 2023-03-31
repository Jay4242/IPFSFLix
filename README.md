# IPFSFLix

--------

### Concept

IPFS has features that go well with serving videos across networks.

With the IPFS network mounted to a local machine Jellyfin & Plex are capable of having cached video libraries.

Devices with limited storage can have access to a huge on-demand library.  Say a Raspberry Pi at an office, relative's home, etc.

-------


#### IPNS

'Server' nodes with a large amount of storage can create IPNS keys for collections of files.  They can 'publish' updates to this address as they add/remove content.

'Client' nodes then resolve this IPNS address to get updates.

All nodes can be clients & servers.  Anything cached to a 'client' node acts as +1 source for the network.

------

#### ipfs-add-movies.bash

Adds videos using the IPFS 'filestore' (to not use extra space) to IPFS & the IPFS MFS filesystem under '/movies/'

------

#### ipns-refresh.bash

Uses a text file such as the ipfs-namemap.list.sample to create symlinks in a specified directory.  This resolves the IPNS address to an IPFS address to prevent the directory from hanging when IPNS is unresovlable.  


------
