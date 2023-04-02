#!/bin/bash
if [ -e ~/.config/ipfsflix.conf ] ; then
  source ~/.config/ipfsflix.conf || echo "~/.config/ipfsflix.conf not sourced correctly"
  if [ -z "${confdir}" ] ; then
    echo "confdir not set correctly in config file at ~/.config/ipfsflix.conf"
    exit 1
  fi
else
  echo "Configuration not found at ~/.config/ipfsflix.conf"
  exit 1
fi

url="$1"
read -p "Name for wrapping directory: " dir
echo "Which IPFS_PATH to save under?"
select path in $(cat "${confdir}ipfsflix-paths.list" ) ; do
  export IPFS_PATH="${path}"
  break
done

echo "Which IPFS MFS Directory to save under?"
select bdir in $(ipfs files ls) ; do
  if ipfs files ls "/${bdir}/" | grep "${dir}" ; then
    if [ -n "${dir}" ] ; then
      ipfs files rm -rf "/${bdir}/${dir}"
    fi
  fi
  cid=$(ipfs add -w --nocopy --to-files="/${bdir}/${dir}" "${url}" | tail -n 1 | awk -F' ' '{print $2}') && echo "${url}::/${bdir}/${dir}::${cid}::${IPFS_PATH}" >> ${confdir}ipfsflix-filesystem.list || exit 1
  echo ""
  break
done
