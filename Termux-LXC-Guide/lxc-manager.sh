#!/bin/bash

DEFAULT_CONTAINER="debian12"
DEFAULT_USER="tst"
LBLUE="\033[0;94m"
RED="\033[0;33m"
BRED='\033[1;31m'
NC="\033[0m"
BGREEN='\033[1;32m'

CONTAINERS_PATH="/data/data/com.termux/files/usr/var/lib/lxc"
GITHUB_DIR="${HOME}/Termux-LXC-Guide"
DEPENDENCIES="lxc tsu nano mount-utils pulseaudio termux-tools dos2unix curl git iptables dnsmasq termux-x11-nightly bindfs"

setup_lxc() {
  # Check if Termux dependencies are installed
  for i in root-repo x11-repo tur-repo ${DEPENDENCIES}; do
    if ! dpkg-query -W -f"\${db:Status-Abbrev}\n" "${i}" 2>/dev/null | grep -Eq "^.i"; then
      [ -z "${apt_update}" ] && { apt update || exit 1; } && apt_update=true
      yes | pkg install -y "${i}" || exit 1
    fi
  done
  
  clear 2>/dev/null
  
  # Set correct permissions for configurations directory
  # Helpful if you create new configs on the go and don't want to chown, chgrp and chmod them every time to be Termux compatible
  sudo test -d "${GITHUB_DIR}" && export SUDO_USER="$(sudo /system/bin/pm list packages -U com.termux | grep -F "package:com.termux " | sed 's/.*://')" || exit 1
  sudo chown -R "${SUDO_USER}:${SUDO_USER}" "${GITHUB_DIR}" || exit 1
  sudo chgrp -R "${SUDO_USER}" "${GITHUB_DIR}"
  sudo restorecon -R "${GITHUB_DIR}" 2>/dev/null >/dev/null
  chmod 755 "${GITHUB_DIR}"
  cd "${GITHUB_DIR}"
  chmod 755 ".git" 2>/dev/null >/dev/null
  find . -maxdepth 1 -type f -name "*\.sh" -exec chmod 744 "{}" \;
  find . -maxdepth 1 -type f ! -name "*\.sh" -exec chmod 644 "{}" \;
  for i in $(find . -maxdepth 1 -type d ! -name "\." ! -name "\.git"); do
    find "${i}" -type d -exec chmod 755 "{}" \;
    find "${i}" -type f -name "*\.sh" -exec chmod 744 "{}" \;
    find "${i}" -type f -name "*\.sh" -exec dos2unix "{}" \; 2>/dev/null >/dev/null
    find "${i}" -type f ! -name "*\.sh" -exec chmod 644 "{}" \;
  done
  
  # Correctly configure LXC
  # Fixes colors, network, etc.
  mkdir -p "${PREFIX}/etc/lxc"
  sudo chown -R "${SUDO_USER}:${SUDO_USER}" "${PREFIX}/etc/lxc"
  sudo chgrp -R "${SUDO_USER}" "${PREFIX}/etc/lxc"
  sudo restorecon -R "${PREFIX}/etc/lxc" 2>/dev/null >/dev/null
  chmod 700 "${PREFIX}/etc/lxc"
  rm -rf "${PREFIX}/etc/lxc/default.conf"
  
  required_configuration='lxc.net.0.type = none
lxc.hook.version = 1
lxc.tty.max = 10
lxc.environment = TERM
lxc.cgroup.devices.allow =
lxc.cgroup.devices.deny =
lxc.mount.auto = cgroup:mixed sys:mixed proc:mixed
lxc.hook.pre-start = "'${GITHUB_DIR}'/src/required-lxc-configuration/scripts/utils/utils.pre-start.sh"
lxc.hook.start-host = "'${GITHUB_DIR}'/src/required-lxc-configuration/scripts/utils/utils.start-host.sh"
lxc.hook.start = "/scripts/lxc_startup.sh"
lxc.hook.post-stop = "'${GITHUB_DIR}'/src/required-lxc-configuration/scripts/utils/utils.post-stop.sh"
lxc.mount.entry = '${GITHUB_DIR}'/scripts scripts none bind,create=dir 0 0
lxc.mount.entry = '${TMPDIR}' tmp none bind,create=dir 0 0
lxc.mount.entry = /data/lxc-storage media none rbind,create=dir 0 0
lxc.mount.entry = '${GITHUB_DIR}'/src/required-lxc-configuration/lxc_fstab etc/fstab none bind,create=file 0 0
'
  
  echo "${required_configuration}" > "${PREFIX}/etc/lxc/default.conf"
  sudo chown "${SUDO_USER}:${SUDO_USER}" "${PREFIX}/etc/lxc/default.conf"
  sudo chgrp "${SUDO_USER}" "${PREFIX}/etc/lxc/default.conf"
  sudo restorecon "${PREFIX}/etc/lxc/default.conf" 2>/dev/null >/dev/null
  chmod 644 "${PREFIX}/etc/lxc/default.conf"
  sudo sh -c "export SUDO_USER='${SUDO_USER}'; src/required-lxc-configuration/scripts/utils/utils.lxc-net.configuration.sh" || exit 1
  
  dpkg -i "${GITHUB_DIR}/rsync_fixed.deb"
  
  echo -e "
  
  
${BGREEN}Use available lxc commands by typing lxc or lxc help${NC}
   
   
  "
  
  if [[ ! -L "$PREFIX/bin/lxc" ]]; then
    ln -s "$HOME/$0" "$PREFIX/bin/lxc"
  fi
}

cli() {
  if [[ "$1" == "--run--" ]];
  then
    shift
    run="yes"
    if [[ "$#" -lt 3 ]]; then
      echo "Usage: lxc run container_name user_name commands"
      exit 3
    fi
    cmds="${*:3}"
  fi
  local cname="${1:-$DEFAULT_CONTAINER}"
  local uname="${2:-$DEFAULT_USER}"
  
  if [[ -n "${1}" && -z "${2}" ]];
  then
    echo "Usage: lxc cli container_name user_name"
    return 1
  fi
  if sudo lxc-info "$cname" | grep -q "doesn't exist"; then
    echo "container $cname doesn't exist"
    return 2
  fi
  if sudo lxc-info "$cname" | grep -q "STOPPED"; then
    sudo lxc-start "$cname"
  fi
  if [[ "$run" =~ "yes" ]]; then
    sudo lxc-attach -n "$cname" --clear-env -q -- su "$uname" -l -c "$cmds"
  else
    sudo lxc-attach -n "$cname" --clear-env -q -- su "$uname" -l
  fi
}


if [[ ! -L "$PREFIX/bin/lxc" ]];
then
  setup_lxc
  exit
fi

#######################################
#######################################
#######################################
case $1 in
  "help" | "")
    ls "$PREFIX"/bin | grep lxc | sed 's/-/ /'
    echo ""
    echo "Extra commands except regular binaries: help|new|cli|gui|run|set|restart|setup|backup|restore|force-stop"
    echo ""
    ;;
  "setup")
    setup_lxc
  ;;
  "new")
    sudo lxc-create -n $2 -t download -B overlayfs -- --no-validate -d $3 -r $4 -a arm64
  ;;
  "cli")
    cli "$2" "$3"
  ;;
  "gui")
    if [[ "$*" == *"-k"* ]]; then
      PIDS=$(sudo pgrep -f -d' ' 'dbus|xfce|x11')
      [ -n "$PIDS" ] && sudo kill -9 $PIDS
      sudo rm -rf "$TMPDIR"/.*
      sudo rm -rf "$TMPDIR"/*
      exit
    fi
    DEFAULT_CONTAINER="${2:-$DEFAULT_CONTAINER}"
    DEFAULT_USER="${3:-$DEFAULT_USER}"
    if sudo lxc-info "$DEFAULT_CONTAINER" | grep -q "STOPPED" && sudo lxc-ls | grep -q "$DEFAULT_CONTAINER"; then
      sudo lxc-start "$DEFAULT_CONTAINER"
      if [[ $? > 0 ]]; then
        echo "There's some issue going on"
        exit $?
      fi
    fi
    (
    sleep 2
    termux-x11 :0 &
    sleep 4
    sudo lxc-attach -n "$DEFAULT_CONTAINER" --clear-env -q -- su "$DEFAULT_USER" -l -c "nohup sh -c 'export DISPLAY=:0 && dbus-launch --exit-with-session startxfce4' &> /dev/null &"
    ) &
    cli "$DEFAULT_CONTAINER" "$DEFAULT_USER"
  ;;
  "run")
    cli "--run--" "$2" "$3" "${@:4}"
    ;;
  "restart")
    if [[ $# -eq 2 ]]; then
      sudo lxc-stop -k "$2"
      sudo lxc-start "$2"
    else
      echo "Usage: lxc restart container_name"
    fi
    ;;
  "set")
    if [[ -z "$2" || -z "$3" ]]; then
      echo "Usage: set new_container_name new_user_name"
    else
      sed -i "0,/^DEFAULT_CONTAINER=\"/s/^DEFAULT_CONTAINER=\"[^\"]*\"/DEFAULT_CONTAINER=\"${2}\"/" "$GITHUB_DIR/lxc-manager.sh"
      
      sed -i "0,/^DEFAULT_USER=\"/s/^DEFAULT_USER=\"[^\"]*\"/DEFAULT_USER=\"${3}\"/" "$GITHUB_DIR/lxc-manager.sh"
    fi
    ;;
  "snapshot")
    if [[ "$@" =~ "-c" && $# -eq 3 ]]; then
      if sudo lxc-info "$3" | grep -q "doesn't exist";
      then
        echo "container $3 doesn't exist"
        return 2
      fi
      read -p "Enter your comment: " comment
      echo -e "${LBLUE} $comment\n ${NC}" > "$GITHUB_DIR/snapshot-comment.txt"
      sudo lxc-snapshot "$3" --comment="$GITHUB_DIR/snapshot-comment.txt"
      sudo rm -rf "$GITHUB_DIR/snapshot-comment.txt"
    else
      shift 1
      sudo lxc-snapshot "$@"
    fi
  ;;
  "backup")
    for arg in "$@"; do
      if [[ "$arg" == "-L" || "$arg" == "-r" ]]; then
        if [[ "$arg" == "-L" ]]; then
          ls "$GITHUB_DIR/container_backups" | awk '{print "\033[01;32m" substr($0, 1, length($0)-7) "\033[0m"}'
          exit
        fi
        if [[ "$arg" == "-r" ]]; then
          if [[ ! $# -eq 3 ]]; then
            echo "usage: lxc backup -r container_name"
            exit
          fi
          for dir in "${GITHUB_DIR}/container_backups"/*; do
            CONTAINERS_NAME=$(basename "$dir")
            if [[ "$CONTAINERS_NAME" == "$3.tar.gz" ]]; then
                sudo rm -rf $dir
              exit
            fi
          done
        fi
      fi
    done
    if [[ ! $# -eq 2 ]]; then
      echo "usage: lxc backup container_name"
      exit
    fi
    found=false
    for dir in "${CONTAINERS_PATH}"/*; do
      CONTAINERS_NAME=$(basename "$dir")
      if [[ "$CONTAINERS_NAME" == "$2" ]]; then
        if sudo lxc-info "$2" | grep -q "RUNNING"; then
          echo -e "${BRED}Container $2 is running, shutdown the container to backup${NC}"
          exit
        fi
        sudo tar czvf --xattrs --acls --selinux --preserve-permissions "$GITHUB_DIR/container_backups/${2}.tar.gz" -C "${CONTAINERS_PATH}" "${2}"
        found=true
        break
      fi
    done
    if ! $found; then
      echo "No container found with the name '$2'."
    fi
  ;;
  "restore")
    if [[ ! $# -eq 2 ]]; then
      echo "usage: lxc restore container_name"
      exit
    fi
    found=false
    for dir in "${GITHUB_DIR}/container_backups"/*; do
      CONTAINERS_NAME=$(basename "$dir")
      if [[ "$CONTAINERS_NAME" == "$2.tar.gz" ]]; then
        if sudo lxc-ls | grep -q "$2"; then
          echo -e "${BRED}Container $2 already exists${NC}"
          exit
        fi
        sudo tar xzvf --xattrs --acls --selinux --preserve-permissions "$GITHUB_DIR/container_backups/${2}.tar.gz" -C "${CONTAINERS_PATH}/"
        found=true
        break
      fi
    done
    if ! $found; then
      echo "No container found with the name '$2'."
    fi
  ;;
  "force-stop")
    if [[ ! $# -eq 2 ]]; then
      echo "usage: lxc restore container_name"
      exit
    fi
    PIDS=$(sudo pgrep -f -d' ' 'lxc')
    [ -n "$PIDS" ] && sudo kill -9 $PIDS
  ;;
  *)
    sudo lxc-"$@" 2> >(grep -v "No such file or directory" | sed 's/^[ \t]*//')
    if [[ $? -eq 127 ]]; then
        echo "lxc $1: command not found"
    fi
  ;;
esac