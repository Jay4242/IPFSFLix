# IPFSFLix

--------

### Concept

IPFS has features that go well with serving videos across networks.

With the IPFS network mounted to a local machine Jellyfin & Plex are capable of having cached video libraries.

Devices with limited storage can have access to a huge on-demand library.  Say a Raspberry Pi at an office, relative's home, etc.

IPFS by itself can easily turn into a confusing maze.  
Media Organizers like Jellyfin & Plex seem like a natural fit to this maze.

-------

#### IPNS

'Server' nodes with a large amount of storage can create IPNS keys for collections of files.  They can 'publish' updates to this address as they add/remove content.

'Client' nodes then resolve this IPNS address to get updates.

All nodes can be clients & servers.  Anything cached to a 'client' node acts as +1 source for the network.

------

#### ipfsflix-add-movies.bash

Adds videos using the IPFS 'filestore' (to not use extra space) to IPFS & the IPFS MFS filesystem under '/movies/'

You need to have created a /movies/ directory with a command like `ipfs files mkdir /movies/`

Currently, only adds the main video, no subs or other files.  Only grabs `mp4` & `mkv` files.

Run in the directory you have a bunch of `mp4` & `mkv` files.

It keeps a file list at `${confdir}/ipfsflix-filesystem.list`.

------

#### ipfsflix-add-file.bash `{file/directory name}`

Adds a single file/directory to ipfsflix.  Ignores any *.txt, *.nfo, *.rar, *.exe files if it's a directory being added.

Prompts for `IPFS_PATH` to use.

Prompts for IPFS MFS location to save.  (currently one level)

It keeps a file list at `${confdir}/ipfsflix-filesystem.list`.

------

#### ipfsflix-ipns-refresh.bash

Uses a text file such as the `ipfsflix-namemap.list.sample` to create symlinks in a specified directory.  This resolves the IPNS address to an IPFS address to prevent the directory from hanging when IPNS is unresovlable.  

------

#### ipfsflix-publish.bash

Publishes your IPFS MFS directories to their corresponding keys.  Publishing 'movies' with the 'movies' key, 'series' with the 'series' key, for example, etc.

------

#### ipfsflix-rm-file.bash `{search phrase}`

Searches the `ipfs-filesystem.list` file to prompt for the deletion of files from the IPFS MFS, the IPFS pin, and then finally the `ipfs-filesystem.list` itself.

------

#### ipfsflix-namemap.list.sample

A text file that stores the IPNS addresses to resolve to symlinks.

##### Fields
 - Relative Path to IPFS/IPNS Mounts - Used to tell the script where the mounted IPFS/IPNS endpoints will be located.  Useful if you have multiple IPFS mountpoints, perhaps the main swarm and a private swarm.  Something like `../../..` if the /ipfs/ mount is three directories above the symlink directory.
 - Symlink name - The name you want to give the symlink directory.
 - IPNS address - The IPNS address that will be resolved for that symlink.
 - IPFS_PATH - The IPFS_PATH needed to access the right IPFS daemon.  Most people would use `~/.ipfs/` for the default public swarm.
 
Uses '::' separators.
 
Example to a small **public domain** sample of videos,
 
`../../..::ipfs-public-domain::/ipns/k51qzi5uqu5dm003wyasjdmljt5ekqos1ptq73n2l2zplvv9672jqkftlqyica::~/.ipfs/`

Goes in the `confdir` configuration directory set in `~/.config/ipfsflix.conf`.
 
------

#### ipfsflix-paths.list.sample

A list of your IPFS_PATHs.  Most people probably have the main swarm at ~/.ipfs.  If you have private swarm node locations add them here as well.

Goes in the `confdir` configuration directory set in `~/.config/ipfsflix.conf`.

------

#### ipfsflix-filesystem.list.sample

The scripts that add files should add to this file in the `confdir` configuration directory.

`ipfsflix-rm-file.bash` removes lines from this file when files are unpinned and removed from the IPFS MFS.

Goes in the `confdir` configuration directory set in `~/.config/ipfsflix.conf`.

------

### Rough Idea

 1. Add media to IPFS using the IPFS 'filestore.'
 2. Create an IPNS directory that virtually holds that media.
 3. Share this IPNS address with other devices.
 4. Other devices symlink the IPNS address to the IPFS 'mount' locations.
 5. Jellyfin & Plex add those symlinked directories to their Libraries.
 6. Use Jellyfin & Plex as normal.
 7. Use a Private Swarm if you want privacy.

------

#### Bugs

There's probably lots of bugs.

I don't guarantee that anything here works at any given point.
