#!/usr/bin/env sh

# Post-stop script for LXC containers

export HOME="/data/data/com.termux/files/home"
GITHUB_DIR="${HOME}/Termux-LXC-Guide"

# If container stopped then umount the bind mounted rootfs and restore it's nosuid if it was set
LXC_ROOTFS_PATH=$(echo $LXC_ROOTFS_PATH | cut -d ":" -f 1)
LXC_BASE_PATH=$(echo $LXC_ROOTFS_PATH | sed 's|/rootfs||')

umount -Rl "${LXC_ROOTFS_PATH}"
umount -Rl "${LXC_BASE_PATH}/full_Rootfs"

bash "${GITHUB_DIR}/src/required-lxc-configuration/scripts/utils/utils.storage-mount.sh" umount

exit 0
