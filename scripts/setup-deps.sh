#!/usr/bin/env bash
# setup-deps.sh – Install build dependencies on Ubuntu 22.04
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -qq

apt-get install -y --no-install-recommends \
  # Core build tools
  build-essential \
  autoconf \
  automake \
  libtool \
  pkg-config \
  bison \
  flex \
  gettext \
  # Cross-compilation (MinGW via system, overridden by LLVM-MinGW)
  gcc-mingw-w64-x86-64 \
  gcc-mingw-w64-i686 \
  binutils-mingw-w64-x86-64 \
  binutils-mingw-w64-i686 \
  # Wine build requirements
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
  # Script utilities
  jq \
  curl \
  wget \
  xz-utils \
  zstd \
  git \
  python3 \
  python3-pip \
  # Shader compilation (for Wine's built-in shaders)
  glslang-tools \
  spirv-tools

echo "Dependencies installed."
