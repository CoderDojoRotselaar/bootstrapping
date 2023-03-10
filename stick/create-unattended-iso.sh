#!/bin/bash -eu

# Needed tools: 7z, xorriso

ISO="isos/ubuntu-22.04.2-live-server-amd64.iso"
# ISO="isos/ubuntu-20.04.5-desktop-amd64.iso"

if [[ ! -f "${ISO}" ]]; then
  echo "You should download the Ubuntu live server iso to '${ISO}'"
  exit 1
fi

if [[ ! -d "iso/" ]]; then
  SCRATCH=1
fi

if [[ "${SCRATCH:-}" == "1" ]]; then
  rm -rf iso/
  7z x "${ISO}" -x'![BOOT]' -oiso

  # Update boot flags with cloud-init autoinstall:
  ## Should look similar to this: initrd=/casper/initrd quiet autoinstall ds=nocloud;s=/cdrom/nocloud/ ---
  set +e
  sed -i 's|---|autoinstall ds=nocloud\\\;s=/cdrom/nocloud/ ---|g' iso/boot/grub/grub.cfg
  sed -i 's|---|autoinstall ds=nocloud\\\;s=/cdrom/nocloud/ ---|g' iso/boot/grub/loopback.cfg
  sed -i 's|---|autoinstall ds=nocloud;s=/cdrom/nocloud/ ---|g' iso/isolinux/txt.cfg
  set -e

  # Disable mandatory md5 checksum on boot:
  md5sum iso/.disk/info >iso/md5sum.txt
  sed -i 's|iso/|./|g' iso/md5sum.txt
fi

rsync -av --delete nocloud/ iso/nocloud/

7z -y x "${ISO}" '[BOOT]'

rm -v -f coderdojo-autoinstall.iso

xorriso -as mkisofs -r \
  -V 'CoderDojo automated installation' \
  -o coderdojo-autoinstall.iso \
  --grub2-mbr "./[BOOT]/1-Boot-NoEmul.img" \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "./[BOOT]/2-Boot-NoEmul.img" \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c '/boot.catalog' \
  -b '/boot/grub/i386-pc/eltorito.img' \
  -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2:::' \
  -no-emul-boot \
  iso
