#!/usr/bin/env bash
# Uninstall NVIDIA stack (driver + fabric manager + libs) and CUDA Toolkit on Ubuntu 24.04
# Safe-ish purge with cleanup and reset steps.
set -euo pipefail

echo "==> Stopping services"
systemctl stop ollama 2>/dev/null || true
systemctl stop nvidia-fabricmanager 2>/dev/null || true

echo "==> Disable services"
systemctl disable nvidia-fabricmanager 2>/dev/null || true

echo "==> Remove APT holds (if any)"
apt-mark unhold \
  nvidia-driver-575 nvidia-dkms-575 nvidia-kernel-common-575 nvidia-kernel-source-575 \
  nvidia-utils-575 nvidia-compute-utils-575 \
  libnvidia-compute-575 libnvidia-gl-575 libnvidia-extra-575 \
  libnvidia-decode-575 libnvidia-encode-575 libnvidia-fbc1-575 libnvidia-cfg1-575 \
  xserver-xorg-video-nvidia-575 nvidia-fabricmanager-575 2>/dev/null || true

echo "==> Clean up dpkg/apt state (best-effort)"
dpkg --configure -a || true
apt-get -f install -y || true
apt-get update -y

echo "==> Purging NVIDIA driver/libs/fabric and CUDA packages"
# Remove NVIDIA packages
apt-get remove -y --purge \
  'nvidia-*' 'libnvidia-*' 'xserver-xorg-video-nvidia-*' \
  'cuda-*' 'libcud*' || true

echo "==> Autoremove and clean"
apt-get autoremove -y --purge
apt-get clean

echo "==> Remove local CUDA repo (deb-local) & keyring if present"
rm -rf /var/cuda-repo-ubuntu2404-12-9-local 2>/dev/null || true
rm -f /etc/apt/sources.list.d/cuda-ubuntu2404-12-9-local*.list 2>/dev/null || true
rm -f /usr/share/keyrings/cuda-*-keyring.gpg 2>/dev/null || true

echo "==> Remove NVIDIA/CUDA APT preferences (pin files)"
rm -f /etc/apt/preferences.d/nvidia-575-57.pref 2>/dev/null || true
rm -f /etc/apt/preferences.d/cuda-repository-pin-600 2>/dev/null || true

echo "==> Remove CUDA symlinks and leftovers (best-effort)"
rm -f /usr/local/cuda 2>/dev/null || true
rm -rf /usr/local/cuda-* 2>/dev/null || true
rm -rf /usr/share/nvidia /usr/lib/nvidia /lib/firmware/nvidia 2>/dev/null || true

echo "==> Rebuild initramfs (in case nvidia modules were included)"
update-initramfs -u || true

echo "==> Final dpkg/apt sanity pass"
dpkg --configure -a || true
apt-get -f install -y || true
apt-get update -y

echo
echo "==> Uninstall complete."
echo "    Recommended: reboot now to unload any remaining kernel modules."
echo "    Run: sudo reboot"
