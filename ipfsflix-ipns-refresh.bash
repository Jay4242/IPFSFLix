#!/bin/bash
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

set -x
namemap="ipfsflix-namemap.txt"             #Text file with relative/path::symlink-name::/ipns/address::IPFS_PATH for each IPNS address to resolve & symlink.

cd "${symlinkdir}" || exit 1
mapfile -t links < <(find "${symlinkdir}" -maxdepth 1 -type l | sed 's,^\./,,')
for link in "${links[@]}" ; do
  grep -q "${link}" "${confdir}/ipfsflix-namemap.txt" || rm "${link}"
done
mapfile -t ipns < <(cat "${confdir}/ipfsflix-namemap.txt") || exit 1
for ipn in "${ipns[@]}" ; do
  export IPFS_PATH=$(echo "${ipn}" | awk -F'::' '{print $4}')
  vname=$(echo "${ipn}" | awk -F'::' '{print $2 }')
  cid=$(ipfs name resolve --dhtt "${timeout}s" $(echo ${ipn} | awk -F'::' '{print $3}')) || continue
  mcid=$(echo -n "$(echo ${ipn} | awk -F'::' '{print $1}')${cid}")
  if [[ -L "${vname}" ]] ; then
    ecid=$(readlink "${vname}")
    if [[ "${ecid}" == "${mcid}" ]] ; then
      continue
    fi
  fi
  ln -sf "${mcid}" "${vname}" || continue
  timeout ${timeout}s tree "${vname}" > /dev/null
done
