#!/usr/bin/env sh

HOME="/data/data/com.termux/files/home"
GITHUB_DIR="${HOME}/Termux-LXC-Guide"

LXC_ROOTFS_PATH=$(echo "$LXC_ROOTFS_PATH" | cut -d ':' -f 1)
export LXC_BASE_PATH=$(echo "$LXC_ROOTFS_PATH" | sed 's|/rootfs||')

if [[ ! -d "${LXC_BASE_PATH}/full_Rootfs" ]]; then
  mkdir -p "${LXC_BASE_PATH}/full_Rootfs"
fi

nohup bash -c "\
LXC_CONTAINER=\$(lxc-info -n \$LXC_NAME -p) && \
LXC_PID=\$(echo \$LXC_CONTAINER | awk '{print \$2}') && \
bindfs /proc/\$LXC_PID/root \$LXC_BASE_PATH/full_Rootfs" > /dev/null 2>&1 &

