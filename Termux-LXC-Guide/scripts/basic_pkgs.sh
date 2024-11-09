#!/bin/bash

sudo apt install xfce4 xfce4-terminal dbus-x11 xfce4-goodies -y

sudo apt install -y flatpak; sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; sudo chmod u+s /usr/bin/bwrap

sudo apt install zip wget git nano tree htop tmux xz-utils curl bindfs file man-db less man python3 -y