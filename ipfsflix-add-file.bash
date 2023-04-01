#!/bin/bash
#Load configuration file.
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

#Set file to script arguments, exit if the file can't be found.
file=$(find -L "$(pwd)/$*" -print -quit ) || exit 1

#Echo the file so the user can visually confirm.
echo "${file}"

#Select IPFS_PATH
echo "Which IPFS_PATH to save under?"
select path in $(cat ${confdir}/ipfs-paths.list) ; do
  export IPFS_PATH="${path}"
  break
done

#Set virtual directory name using the filename without the extension, unless it's a directory, then set it to its name.
if [ -d "${file}" ] ; then
  dir=$(basename "${file}" )
else
  dir=$(basename "$(echo "${file%.*}")")
fi

#Select IPFS MFS directory.
echo "Which IPFS MFS Directory to save under?"
select bdir in $(ipfs files ls ) ; do

  #If exact directory already exists, remove it.
  if ipfs files ls "/${bdir}/" | grep -q "${dir}" ; then

    #Make sure ${dir} isnt null somehow so we dont wipe out the entire base directory.
    if [ -n "${dir}" ] ; then
      ipfs files rm -rf "/${bdir}/${dir}"
    fi
  fi

  #If the file is a directory, add it with IPFS recursively and ignore problematic files like txt, nfo, rar.
  if [ -d "${file}" ] ; then
    cid=$(ipfs add --ignore="*.txt" --ignore="*.nfo" --ignore="*.rar" --ignore="*.exe" -r --nocopy --to-files="/${bdir}/${dir}" "${file}" | tail -n 1 | awk -F' ' '{print $2}') && echo "${file}::/${bdir}/${dir}::${cid}::${IPFS_PATH}" >> ${confdir}ipfs-filesystem.list || exit 1
    break
  else
    #If adding the file is successful pipe the metadata into ${confdir}ipfs-filesystem.list
    cid=$(ipfs add -w --nocopy --to-files="/${bdir}/${dir}" "${file}" | tail -n 1 | awk -F' ' '{print $2}') && echo "${file}::/${bdir}/${dir}::${cid}::${IPFS_PATH}" >> ${confdir}ipfs-filesystem.list || exit 1
    break
  fi
done
