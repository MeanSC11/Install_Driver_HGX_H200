#!/usr/bin/env bash
# Installs and aligns NVIDIA stack for HGX/NVSwitch on Ubuntu 24.04:
# - Driver 575.57.08
# - Fabric Manager 575.57.08
# - CUDA Toolkit 12.9 (deb-local)
set -euo pipefail

DRIVER_VER="575.57.08"
CUDA_LOCAL_VER="12-9"        # for repo name "cuda-repo-ubuntu2404-12-9-local"
UBUNTU_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"

echo "==> Ubuntu codename: ${UBUNTU_CODENAME}"
if [[ "${UBUNTU_CODENAME}" != "noble" ]]; then
  echo "!! This script is intended for Ubuntu 24.04 (noble) only"; exit 1
fi

echo "==> Stopping related services"
systemctl stop ollama 2>/dev/null || true
systemctl stop nvidia-fabricmanager 2>/dev/null || true

echo "==> Cleaning up any pending dpkg/apt states"
dpkg --configure -a || true
apt-get -f install -y || true
apt-get update -y

echo "==> Adding CUDA keyring (NVIDIA repo) to pull 575.57.08 packages"
if ! dpkg -l | grep -q cuda-keyring; then
  wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
  dpkg -i cuda-keyring_1.1-1_all.deb
  apt-get update -y
fi

cat <<'PREF' >/etc/apt/preferences.d/nvidia-575-57.pref
Package: nvidia-* libnvidia-*
Pin: version 575.57.08*
Pin-Priority: 1001
PREF

echo "==> (Optional) Install/verify CUDA 12.9 (deb-local)"
# If you have already downloaded the deb-local .deb from the archive page, run dpkg -i here
# Example filename (may differ by minor version): cuda-repo-ubuntu2404-12-9-local_12.9.0-1_amd64.deb
# Once installed, it will appear at /var/cuda-repo-ubuntu2404-12-9-local
if [[ ! -d /var/cuda-repo-ubuntu2404-12-9-local ]]; then
  echo "==> CUDA 12.9 deb-local repo not found"
  echo "   - Visit: https://developer.nvidia.com/cuda-12-9-0-download-archive?target_os=Linux&target_arch=x86_64&Distribution=Ubuntu&target_version=24.04&target_type=deb_local"
  echo "   - Download the 'deb-local' .deb file, then run:"
  echo "     dpkg -i <cuda-repo-ubuntu2404-12-9-local_*.deb> && apt-get update"
else
  echo "==> Found deb-local repo: /var/cuda-repo-ubuntu2404-12-9-local"
fi

echo "==> Aligning core packages (common/compute/decode) to 575.57.08 with overwrite allowed"
apt-get install -y --allow-downgrades -o Dpkg::Options::="--force-overwrite" \
  libnvidia-common-575=${DRIVER_VER}-* \
  libnvidia-compute-575=${DRIVER_VER}-* \
  libnvidia-decode-575=${DRIVER_VER}-*

echo "==> Installing full NVIDIA 575.57.08 stack (including Fabric Manager)"
apt-get install -y --allow-downgrades --allow-change-held-packages \
  nvidia-driver-575=${DRIVER_VER}-* \
  nvidia-dkms-575=${DRIVER_VER}-* \
  nvidia-kernel-common-575=${DRIVER_VER}-* \
  nvidia-kernel-source-575=${DRIVER_VER}-* \
  nvidia-utils-575=${DRIVER_VER}-* \
  nvidia-compute-utils-575=${DRIVER_VER}-* \
  libnvidia-gl-575=${DRIVER_VER}-* \
  libnvidia-extra-575=${DRIVER_VER}-* \
  libnvidia-encode-575=${DRIVER_VER}-* \
  libnvidia-fbc1-575=${DRIVER_VER}-* \
  libnvidia-cfg1-575=${DRIVER_VER}-* \
  xserver-xorg-video-nvidia-575=${DRIVER_VER}-* \
  nvidia-fabricmanager-575=${DRIVER_VER}-*

echo "==> Building DKMS modules and updating initramfs"
dkms autoinstall -k "$(uname -r)" || true
update-initramfs -u

echo "==> Enabling Fabric Manager & Persistence mode on boot"
systemctl enable nvidia-fabricmanager || true

echo "==> Pinning NVIDIA packages to prevent accidental upgrades"
apt-mark hold \
  nvidia-driver-575 nvidia-dkms-575 nvidia-kernel-common-575 nvidia-kernel-source-575 \
  nvidia-utils-575 nvidia-compute-utils-575 \
  libnvidia-compute-575 libnvidia-gl-575 libnvidia-extra-575 \
  libnvidia-decode-575 libnvidia-encode-575 libnvidia-fbc1-575 libnvidia-cfg1-575 \
  xserver-xorg-video-nvidia-575 nvidia-fabricmanager-575

echo
echo "==> Next steps: reboot the system, then verify installation with:"
echo "   nvidia-smi"
echo "   /usr/bin/nv-fabricmanager --version"
echo "   nvcc --version"
echo "   cat /usr/local/cuda/version.txt"
echo "sudo reboot"
