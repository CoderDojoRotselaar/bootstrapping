#!/bin/bash

# Needed tools: 7z, xorriso

ISO="isos/ubuntu-20.04.3-live-server-amd64.iso"

if [[ ! -f "${ISO}" ]]; then
  echo "You should download the Ubuntu 20.04.3 live server iso to '${ISO}'"
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
  sed -i 's|---|autoinstall ds=nocloud\\\;s=/cdrom/nocloud/ ---|g' iso/boot/grub/grub.cfg
  sed -i 's|---|autoinstall ds=nocloud;s=/cdrom/nocloud/ ---|g' iso/isolinux/txt.cfg

  # Disable mandatory md5 checksum on boot:
  md5sum iso/.disk/info >iso/md5sum.txt
  sed -i 's|iso/|./|g' iso/md5sum.txt
fi

rsync -av --delete nocloud/ iso/nocloud/

xorriso -as mkisofs -r \
  -V "CoderDojo automated installation" \
  -o coderdojo-autoinstall.iso \
  -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \
  -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
  -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
  -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin \
  iso/boot iso
