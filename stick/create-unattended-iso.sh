#!/usr/bin/env bash

# file names & paths
tmp="$(pwd)" # destination folder to store the final iso file

# define download function
# courtesy of http://fitnr.com/showing-file-download-progress-using-wget.html
download() {
  local url=$1
  echo -n "    "
  wget --progress=dot $url 2>&1 | grep --line-buffered "%" |
    sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
  echo -ne "\b\b\b\b"
  echo " DONE"
}

# print a pretty header
echo
echo " +---------------------------------------------------+"
echo " |            UNATTENDED UBUNTU ISO MAKER            |"
echo " +---------------------------------------------------+"
echo

# ask if script runs without sudo or root priveleges
if [ $UID != 0 ]; then
  echo " you need sudo privileges to run this script, or run it as root"
  exit 1
fi

#get the latest versions of Ubuntu LTS

tmphtml=$tmp/tmphtml
rm $tmphtml >/dev/null 2>&1
wget -O $tmphtml 'http://releases.ubuntu.com/' >/dev/null 2>&1

ubuntu=bionic
ubuntu_vers=$(fgrep -i "$ubuntu" $tmphtml | head -1 | awk '{print $6}')

download_file="ubuntu-$ubuntu_vers-server-amd64.iso"
download_location="http://cdimage.ubuntu.com/releases/$ubuntu/release/"
new_iso_name="coderdojo-unattended-$ubuntu.iso"

if [ -f /etc/timezone ]; then
  timezone=$(cat /etc/timezone)
elif [ -h /etc/localtime ]; then
  timezone=$(readlink /etc/localtime | sed "s/\/usr\/share\/zoneinfo\///")
else
  checksum=$(md5sum /etc/localtime | cut -d' ' -f1)
  timezone=$(find /usr/share/zoneinfo/ -type f -exec md5sum {} \; | grep "^$checksum" | sed "s/.*\/usr\/share\/zoneinfo\///" | head -n 1)
fi

custom_postinstall_script=
fullname=coderdojo
username=coderdojo
hostname="coderdojo"
pwhash='x'
[[ -f unattended-parameters.env ]] && source unattended-parameters.env # override params here

if [[ "${pwhash}" == "x" ]]; then
  echo "No default password set in 'unattended-parameters.env'. You may not be able to log in!"
fi

# download the ubuntu iso. If it already exists, do not delete in the end.
cd $tmp
if [[ ! -f $tmp/$download_file ]]; then
  echo -n " downloading $download_file: "
  download "$download_location/$download_file"
fi
if [[ ! -f $tmp/$download_file ]]; then
  echo "Error: Failed to download ISO: $download_location$download_file"
  echo "This file may have moved or may no longer exist."
  echo
  echo "You can download it manually and move it to $tmp/$download_file"
  echo "Then run this script again."
  exit 1
fi

# download coderdojo seed file
seed_file="coderdojo.seed"
if [[ ! -f $tmp/$seed_file ]]; then
  echo -n " downloading $seed_file: "
  download "https://raw.githubusercontent.com/CoderDojoRotselaar/bootstrapping/master/$seed_file"
fi

# create working folders
echo " remastering your iso file"
mkdir -p $tmp
mkdir -p $tmp/iso_org
mkdir -p $tmp/iso_new

# mount the image
if grep -qs $tmp/iso_org /proc/mounts; then
  echo " image is already mounted, continue"
else
  (mount -o loop $tmp/$download_file $tmp/iso_org >/dev/null 2>&1)
fi

# copy the iso contents to the working directory
cp -rT $tmp/iso_org $tmp/iso_new &>/dev/null

# set the language for the installation menu
#doesn't work for 16.04
echo en >$tmp/iso_new/isolinux/lang

# copy the coderdojo seed file to the iso
cp -rT $tmp/$seed_file $tmp/iso_new/preseed/$seed_file

if [[ -n "${custom_postinstall_script}" ]]; then
  custom_postinstall_script_basename=$(basename "${custom_postinstall_script}")
  cp -p "${custom_postinstall_script}" "$tmp/iso_new/${custom_postinstall_script_basename}"
fi

cat <<EOF >$tmp/iso_new/post-install.sh
#!/bin/bash

wget https://raw.githubusercontent.com/CoderDojoRotselaar/bootstrapping/master/predeploy.sh -O /tmp/predeploy.sh; \
bash /tmp/predeploy.sh

if [[ -f "/tmp/${custom_postinstall_script_basename}" ]]; then
  bash "/tmp/${custom_postinstall_script_basename}"
fi
EOF

cat <<EOF >>$tmp/iso_new/preseed/$seed_file
${extra_preseed}
EOF
# include firstrun script
cat <<EOF >>$tmp/iso_new/preseed/$seed_file
# setup postinstall script
d-i preseed/late_command                                    string      \
  lvresize -L 8G /dev/coderdojo/root; resize2fs /dev/coderdojo/root; \
  cp -p /cdrom/post-install.sh "/cdrom/${custom_postinstall_script_basename}" /target/tmp/; \
  chroot /target /bin/bash /tmp/post-install.sh

EOF

# update the seed file to reflect the users' choices
# the normal separator for sed is /, but both the password and the timezone may contain it
# so instead, I am using @
sed -i "s@{{username}}@$username@g" $tmp/iso_new/preseed/$seed_file
sed -i "s@{{pwhash}}@$pwhash@g" $tmp/iso_new/preseed/$seed_file
sed -i "s@{{hostname}}@$hostname@g" $tmp/iso_new/preseed/$seed_file
sed -i "s@{{timezone}}@$timezone@g" $tmp/iso_new/preseed/$seed_file

# calculate checksum for seed file
seed_checksum=$(md5sum $tmp/iso_new/preseed/$seed_file | awk '{print $1}')

# add the autoinstall option to the menu
cat <<EOF >$tmp/iso_new/isolinux/txt.cfg
label autoinstall
menu label ^Autoinstall CoderDojo
kernel /install/vmlinuz
append initrd=/install/initrd.gz auto=true priority=high file=/cdrom/preseed/${seed_file} preseed-md5=$seed_checksum preseed-md5=$seed_checksum --
EOF

sed 's/^timeout.*/timeout 50/' -i $tmp/iso_new/isolinux/isolinux.cfg

# add the autoinstall option to the menu for USB Boot
cat <<EOF >$tmp/iso_new/boot/grub/grub.cfg
if loadfont /boot/grub/font.pf2 ; then
  set gfxmode=auto
  insmod efi_gop
  insmod efi_uga
  insmod gfxterm
  terminal_output gfxterm
fi

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

set timeout=1
menuentry "Autoinstall CoderDojo" {
  set gfxpayload=keep
  linux /install/vmlinuz append initrd=/install/initrd.gz auto=true priority=high file=/cdrom/preseed/${seed_file} --
  initrd  /install/initrd.gz
}
EOF

echo " creating the remastered iso"
cd $tmp/iso_new
mkisofs -D -r -V "CODERDOJO_UBUNTU" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o $tmp/$new_iso_name . &>/dev/null

# make iso bootable (for dd'ing to  USB stick)
isohybrid $tmp/$new_iso_name

# cleanup
umount $tmp/iso_org
rm -rf $tmp/iso_new
rm -rf $tmp/iso_org
rm -rf $tmphtml

chown $SUDO_USER: $tmp/$new_iso_name

# print info to user
echo " -----"
echo " finished remastering your ubuntu iso file"
echo " the new file is located at: $tmp/$new_iso_name"
echo " your username is: $username"
echo " your hostname is: $hostname"
echo " your timezone is: $timezone"
echo

# unset vars
unset username
unset hostname
unset timezone
unset pwhash
unset download_file
unset download_location
unset new_iso_name
unset tmp
unset seed_file
