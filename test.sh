#!/bin/sh

set -e

_die()
{
  echo "$*" >&2
  kill -s TERM "$$"
}

_requires()
{
  for i; do
    command -v "$i" 1>/dev/null 2>/dev/null || _die "Dependency '$i' not found, please install it separately"
  done
}

_main()
{
  _requires "wget"

  mkdir -p build && cd build

  # Use jq to fetch latest flatimage version from github
  mkdir -p bin
  [ -f "bin/jq" ] || wget -O bin/jq "https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux-amd64"
  [ -f "bin/xz" ] || wget -O bin/xz "https://github.com/ruanformigoni/xz-static-musl/releases/download/fec8a15/xz"
  [ -f "bin/busybox" ] || wget -O bin/busybox "https://github.com/ruanformigoni/busybox-static-musl/releases/download/7e2c5b6/busybox-x86_64"
  ln -sf busybox bin/tar
  chmod +x ./bin/*
  export PATH="$(pwd)/bin:$PATH"

  # Download flatimage
  IMAGE="./bin/arch.flatimage"
  [ -f "$IMAGE" ] || wget -O "$IMAGE" "$(curl -H "Accept: application/vnd.github+json" \
    https://api.github.com/repos/ruanformigoni/flatimage/releases/latest 2>/dev/null \
    | jq -e -r '.assets.[].browser_download_url | match(".*arch.flatimage$").string')"
  chmod +x "$IMAGE"

  # Enable network
  "$IMAGE" fim-perms set network

  # Update image
  "$IMAGE" fim-root pacman -Syu --noconfirm

  # Install dependencies
  ## General
  "$IMAGE" fim-root pacman -S --noconfirm xorg-server mesa lib32-mesa glxinfo lib32-gcc-libs \
    gcc-libs pcre freetype2 lib32-freetype2
  ## Video AMD/Intel
  "$IMAGE" fim-root pacman -S --noconfirm xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon vulkan-tools
  "$IMAGE" fim-root pacman -S --noconfirm xf86-video-intel vulkan-intel lib32-vulkan-intel vulkan-tools
  "$IMAGE" fim-root pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-tools

  # Install steam
  ## Select the appropriated drivers for your GPU when asked
  "$IMAGE" fim-root pacman -S --noconfirm lutris

  # Clear cache
  "$IMAGE" fim-root pacman -Scc --noconfirm

  # Set permissions
  "$IMAGE" fim-perms set media,audio,wayland,xorg,udev,dbus_user,usb,input,gpu,network

  # Configure user name and home directory
  "$IMAGE" fim-exec mkdir -p /home/lutris
  "$IMAGE" fim-env add 'USER=lutris' \
    'HOME=/home/lutris' \
    'XDG_CONFIG_HOME=/home/lutris/.config' \
    'XDG_DATA_HOME=/home/lutris/.local/share'

  # Set command to run by default
  "$IMAGE" fim-boot /usr/bin/lutris

  # Notify the application has started
  "$IMAGE" fim-notify on

_main "$@"
