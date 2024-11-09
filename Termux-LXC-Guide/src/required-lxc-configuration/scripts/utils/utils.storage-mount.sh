#!/usr/bin/env sh

# Define the source and target directories
INTERNAL="/data/media/0"
EXTERNAL="/mnt/media_rw"
TARGET="/data/lxc-storage"

# Run the entire script with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root or with sudo"
  exit
fi

mountJob() {
  for dir in "${EXTERNAL}"/*; do
    if [ -d "$dir" ] && [ -z "$(ls -A "$dir")" ] && { [[ "$(basename "$dir")" == "sdcard" ]] || [[ "$(basename "$dir")" == "usb1" ]] || [[ "$(basename "$dir")" == "usb2" ]]; }; then
    
      rmdir "${dir}" || exit 277
    fi
  done
  
  mkdir -p "${TARGET}" 
  mkdir -p "${TARGET}/internal0"
  bindfs --perms=0777 --chown-ignore --chgrp-ignore "${INTERNAL}" "${TARGET}/internal0"
  
  mkdir -p "${TARGET}/external0"
  bindfs --perms=0777 --chown-ignore --chgrp-ignore "${EXTERNAL}" "${TARGET}/external0"
}

umountJob() {
  if [[ -d "$TARGET" ]]; then
    umount -R "${TARGET}"/* || umount -Rl "${TARGET}"/*
  fi
  rm -rf "${TARGET}"
}

case $1 in
  "mount")
    umountJob
    mountJob
  ;;
  "umount")
    umountJob
  ;;
esac
