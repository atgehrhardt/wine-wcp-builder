#!/usr/bin/env bash
# setup-deps.sh – Install build dependencies on Ubuntu 22.04
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq

# Core build tools + cross-compilation + Wine build requirements + utilities
apt-get install -y --no-install-recommends \
  build-essential \
  autoconf \
  automake \
  libtool \
  pkg-config \
  bison \
  flex \
  gettext \
  gcc-mingw-w64-x86-64 \
  gcc-mingw-w64-i686 \
  binutils-mingw-w64-x86-64 \
  binutils-mingw-w64-i686 \
  libgnutls28-dev \
  libfreetype-dev \
  libfontconfig-dev \
  libxslt1-dev \
  libxml2-dev \
  libpng-dev \
  libjpeg-dev \
  libtiff-dev \
  libdbus-1-dev \
  libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev \
  libvulkan-dev \
  libsdl2-dev \
  libmpg123-dev \
  libopenal-dev \
  libcups2-dev \
  libsane-dev \
  libv4l-dev \
  libkrb5-dev \
  libldap-dev \
  libpcap-dev \
  ocl-icd-opencl-dev \
  libpulse-dev \
  jq \
  curl \
  wget \
  xz-utils \
  zstd \
  git \
  python3 \
  python3-pip \
  glslang-tools \
  spirv-tools

echo "Dependencies installed."
