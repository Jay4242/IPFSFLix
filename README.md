# IPFSFlix

### Concept

IPFSFlix is a suite of bash scripts designed to streamline the process of managing media within IPFS (InterPlanetary File System) and integrating it with media server software like Jellyfin and Plex. The core idea is to leverage IPFS's content-addressing and decentralized storage capabilities to create a distributed, cached video library accessible to multiple devices, even those with limited storage.

By mounting the IPFS network locally, Jellyfin and Plex can treat IPFS as a cached video library. This allows devices like Raspberry Pis or computers in remote locations to access a vast on-demand media collection without requiring the entire library to be stored locally.

### IPNS (InterPlanetary Name System)

IPNS plays a crucial role in IPFSFlix. "Server" nodes with ample storage can create IPNS keys that represent collections of files. As content is added or removed, these nodes "publish" updates to their IPNS addresses.

"Client" nodes then resolve these IPNS addresses to stay synchronized with the content. Importantly, any node can act as both a client and a server. Media cached on a "client" node contributes to the network by providing an additional source for the content.

### Scripts Overview

The IPFSFlix suite includes the following scripts:

*   **ipfsflix-add-movies.bash**: Adds multiple video files to IPFS and the IPFS MFS (Mutable File System) under the `/movies/` directory. It's designed to work with the IPFS filestore (avoiding extra disk space usage). It currently supports `.mp4` and `.mkv` files.

    *   **Prerequisites**: You must first create the `/movies/` directory in IPFS MFS using `ipfs files mkdir /movies/`.
    *   **Usage**: Run this script from the directory containing your `.mp4` and `.mkv` video files.
    *   **Functionality**:
        *   Finds all `.mp4` and `.mkv` files in the current directory.
        *   Prompts the user to confirm adding each movie to IPFS.
        *   Adds the movie to IPFS using the filestore.
        *   Adds the movie's metadata (file path, MFS path, CID, IPFS\_PATH) to `${confdir}/ipfsflix-filesystem.list`.
*   **ipfsflix-add-file.bash {file/directory name}**: Adds a single file or directory to IPFSFlix.

    *   **Functionality**:
        *   Prompts for the `IPFS_PATH` to use.
        *   Prompts for the IPFS MFS location to save the file/directory.
        *   If adding a directory, it ignores files with extensions `.txt`, `.nfo`, `.rar`, and `.exe`.
        *   Adds the file/directory's metadata to `${confdir}/ipfsflix-filesystem.list`.
*   **ipfsflix-add-url.bash {URL of video}**: Adds a video directly from a URL to IPFSFlix.

    *   **Functionality**:
        *   Prompts the user for a directory name to store the downloaded file (since URLs often lack descriptive names).
        *   Prompts for the `IPFS_PATH` and IPFS MFS directory to save the file.
        *   Downloads the video from the provided URL.
        *   Adds the downloaded file to IPFS MFS.
        *   Adds the file's metadata to `${confdir}/ipfsflix-filesystem.list`.
    *   **Important**: This script does *not* save the video permanently to the server's local storage. When the file is accessed over the network, the host machine will re-download the file to serve the IPFS blocks.
*   **ipfsflix-ipns-refresh.bash**: Creates symlinks in a specified directory based on the IPNS addresses defined in a configuration file (e.g., `ipfsflix-namemap.list`). This resolves the IPNS addresses to their corresponding IPFS CIDs, preventing directory access issues when IPNS resolution is slow or unavailable.
*   **ipfsflix-mfs-remap.bash**: Remaps CIDs to their corresponding MFS locations based on the information stored in `ipfsflix-filesystem.list`. This script is useful for recovering from situations where the IPFS MFS loses track of files.
*   **ipfsflix-publish.bash**: Publishes the IPFS MFS directories to their associated IPNS keys. For example, it publishes the `/movies/` directory with the "movies" key, and the `/series/` directory with the "series" key.
*   **ipfsflix-rm-file.bash {search phrase}**: Searches the `ipfs-filesystem.list` file for entries matching the provided search phrase and prompts the user to delete the corresponding files from the IPFS MFS, unpin them from IPFS, and remove the entries from `ipfs-filesystem.list`.

### Configuration Files

The following configuration files are used by the IPFSFlix scripts:

*   **ipfsflix-namemap.list**: A text file that maps IPNS addresses to symlink names.

    *   **Fields (separated by "::")**:
        *   **Relative Path to IPFS/IPNS Mounts**: Specifies the relative path from the symlink directory to the IPFS/IPNS mount points. This is important if you have multiple IPFS mount points (e.g., a main swarm and a private swarm). Example: `../../..` if the `/ipfs/` mount is three directories above the symlink directory.
        *   **Symlink name**: The desired name for the symlink directory.
        *   **IPNS address**: The IPNS address to be resolved for the symlink.
        *   **IPFS\_PATH**: The `IPFS_PATH` required to access the correct IPFS daemon. Most users will use `~/.ipfs/` for the default public swarm.
    *   **Example**:

        ```
        ../../..::ipfs-public-domain::/ipns/k51qzi5uqu5dm003wyasjdmljt5ekqos1ptq73n2l2zplvv9672jqkftlqyica::~/.ipfs/
        ```

        This entry creates a symlink named `ipfs-public-domain` in the symlink directory, which resolves to the given IPNS address using the default IPFS path.
*   **ipfsflix-paths.list**: A list of your `IPFS_PATH` values. This file should contain the paths to your IPFS data directories (e.g., `~/.ipfs`). If you have multiple IPFS nodes (e.g., a private swarm), add their corresponding paths to this file.
*   **ipfsflix-filesystem.list**: This file is automatically maintained by the `ipfsflix-add-movies.bash`, `ipfsflix-add-file.bash`, `ipfsflix-add-url.bash`, and `ipfsflix-rm-file.bash` scripts. It stores metadata about the files added to IPFSFlix, including their file paths, MFS paths, CIDs, and IPFS\_PATH values.

    *   **Fields (separated by "::")**:
        *   **File Path**: The original path to the file on your system.
        *   **MFS Path**: The path to the file within the IPFS MFS.
        *   **CID**: The content identifier (CID) of the file in IPFS.
        *   **IPFS\_PATH**: The IPFS path used when adding the file.

### Setup and Usage

1.  **Install IPFS**: Ensure that IPFS is installed and configured on your system.
2.  **Configure IPFSFlix**:
    *   Edit the `~/.config/ipfsflix.conf` file to set the correct values for `confdir`, `symlinkdir`, and `timeout`.
    *   Create the `confdir` directory (e.g., `mkdir -p ~/.conf/ipfsflix/`).
    *   Populate the `ipfsflix-paths.list` file with your IPFS paths.
    *   Create the `ipfsflix-namemap.list` file and add entries for the IPNS addresses you want to use.
3.  **Add Media to IPFS**: Use the `ipfsflix-add-movies.bash`, `ipfsflix-add-file.bash`, or `ipfsflix-add-url.bash` scripts to add your media to IPFS.
4.  **Refresh IPNS Symlinks**: Run the `ipfsflix-ipns-refresh.bash` script to create or update the symlinks in your symlink directory.
5.  **Configure Jellyfin/Plex**: Add the symlink directory (specified in `symlinkdir` in `~/.config/ipfsflix.conf`) to your Jellyfin or Plex library.
6.  **Publish IPNS Names**: Use the `ipfsflix-publish.bash` script to publish your IPFS MFS directories to their corresponding IPNS keys.

### Rough Idea

1.  Add media to IPFS using the IPFS 'filestore.'
2.  Create an IPNS directory that virtually holds that media.
3.  Share this IPNS address with other devices.
4.  Other devices symlink the IPNS address to the IPFS 'mount' locations.
5.  Jellyfin & Plex add those symlinked directories to their Libraries.
6.  Use Jellyfin & Plex as normal.
7.  Use a Private Swarm if you want privacy.

### Bugs

There's probably lots of bugs.

I don't guarantee that anything here works at any given point.
