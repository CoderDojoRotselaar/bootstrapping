The installation procedure is based on Ubuntu 20.04 LTS Focal.

Attention: the procedures detailed below will completely wipe the target devices!

# Build your own installation stick

The necessary tools are provided to build your own stick. You can find them in the `stick` folder.

If you have an `apt-cacher-ng` running, you can uncomment and change this line in the `user-data` file (change the IP):

```text
proxy: http://192.168.0.4:3142
```

## Secrets

You can also provide a script to initialize secrets. The provided `user-data` checks if a file `secrets.sh` is present in the `nocloud` directory, and executes it. It should be a Bash-compliant shell script.

## Create ISO

When you finished the configuration files, you can create the ISO. If the original ISO is not present yet, you will get a warning. The first time, this will unpack the downloaded iso into a directory called `iso`.

Create the final iso with:

```bash
$ ./create-unattended-iso.sh

7-Zip [64] 16.02 : Copyright (c) 1999-2016 Igor Pavlov : 2016-05-21
[...]
created directory iso/nocloud
[...]
xorriso 1.5.4 : RockRidge filesystem manipulator, libburnia project.
[...]
Writing to 'stdio:coderdojo-autoinstall.iso' completed successfully.
```

You should now find a new iso `coderdojo-autoinstall.iso` in your workdir.

This ISO can be used as an image on an USB stick or a DVD to install devices. The easiest way is to make a bootable USB stick using [Ventoy](https://github.com/ventoy/Ventoy) and add the ISO to the USB stick.

# Network boot installation (not updated for 20.04!)

There is a fully-automated network installation option, that runs in Docker. It supports `apt-cacher-ng` to limit external bandwidth. The cache will easily take more than 1 GB of disk space.

## Docker solution

The Docker solution is based on two Docker images, and a docker-compose configuration. It needs a working Docker environment, your "server" needs to be connected via network cable. It also assumes `docker-compose` is installed.

Change this configuration file: `netboot/pxelinux/pxelinux.cfg/default`. The IP should point to the IP of your server.
You may also need to change some parameters in the `docker-compose.yml` (especially the `SUBNET1_INTERFACE`).

When everything is ready change directory to `netboot` and run:

```bash
$ docker-compose up
```

The screen should show the logs of all relevant services.

## Manual configuration

To manually configure the installation server / services, you will need an installation server (e.g. your laptop),
with the following components (NB: not all components need to be on the same server):

- PXE/TFTP server
- DHCP server
- Ubuntu linux kernel and initrd
- apt-cacher-ng [optional]

In this documentation, all these services are on the same server (`192.168.0.4`); you should adjust to your own local configuration.

### PXE/TFTP server

In the root of your PXE/TFTP server directory (default: `/var/lib/tftpboot` or `/tftpboot/pxelinux`), you should find or create a file called `pxelinux.cfg/default`.

Add this to the file:

```text
label autoinstall
menu label ^Autoinstall CoderDojo
kernel ubuntu-installer/amd64/linux
append vga=788 initrd=ubuntu-installer/amd64/initrd.gz auto=true priority=critical preseed/url=tftp://192.168.0.4/coderdojo.seed
```

You can add this (temporarily) to the top of the file if you need to install a large number of devices and don't want to pick the right menu option every time:

```
default autoinstall
```

Check whether there is another `default` option set. Careful, as now all devices booting from the network will now become CoderDojo devices!

### DHCP server

You should configure your DHCP server to point devices to your PXE server when installing the devices.

Basically, you add this to your `dhcpd.conf` file (in the right location):

```text
  next-server 192.168.0.4;
  filename "pxelinux.0";
```

Don't forget to change the ip address to point to your server!

### Ubuntu linux kernel and initrd

In the root of your PXE/TFTP server directory (default: `/var/lib/tftpboot` or `/tftpboot/pxelinux`), you need a linux kernel and initrd ready for net-booting Ubuntu.
You can find the necessary files in the `ubuntu-installer` directory of a `netboot` disk.

For bionic (18.04), you can find the files here: [bionic netboot ubuntu-installer (amd64)](https://github.com/CoderDojoRotselaar/bootstrapping/master/netboot/pxelinux/ubuntu-installer/). Copy the full content of that direcotry to a directory called `ubuntu-installer`. You may also want to copy the other files inside the `pxelinux` directory if you are setting this up from scratch.

You should now have these files (a.o.):

- `/var/lib/tftpboot/pxelinux.cfg/default`
- `/var/lib/tftpboot/pxelinux.0`
- `/var/lib/tftpboot/ubuntu-installer/amd64/initrd.gz`
- `/var/lib/tftpboot/ubuntu-installer/amd64/linux`

These files are referred to in `pxelinux.cfg/default` (see PXE/TFTP server); if you change the location, you should change that configuration file accordingly.

You will also need

### Scripts and seed

You need `coderdojo.network.seed`, `post-install.sh` and `secrets.sh` in the root of the PXE/TFTP server (default: `/var/lib/tftpboot` or `/tftpboot/pxelinux`). You may already have copied the scripts in the previous step.

#### Scripts

You can copy the `post-install.sh` included to the server. It will fetch [the pre-deploy](https://github.com/CoderDojoRotselaar/bootstrapping/blob/master/predeploy.sh) script from github and apply it. This script basically adds [a script](https://github.com/CoderDojoRotselaar/bootstrapping/blob/master/deploy.sh) that runs after rebooting the device.

The `secrets.sh` file is another script that can prepare some secrets (passwords, private keys). A generic example is included (`secrets.example.sh`), but there should never be a real version in this repository. The generic example uses a base64-encoded private key to decode [an encrypted git repository](https://github.com/CoderDojoRotselaar/secrets). This repository then includes all other secrets.

#### Seed

Unattended installation of Ubuntu-based distro's works with a seed file, containing all install-time configuration.

You can use the included seed file (`coderdojo.network.seed`) and adjust it to your needs. Save it as `coderdojo.seed`. If you configured an apt-cache, you can configure it here. You also need to configure the `late_command` to finalize the unattended installation.

```text
# mirror settings apt-cache
d-i mirror/http/proxy                                       string      http://192.168.0.4:3142/

# setup postinstall script
d-i preseed/late_command                                    string      lvresize -L 8G /dev/coderdojo/root; resize2fs /dev/coderdojo/root; chroot /target /bin/bash -c "/usr/bin/curl tftp://192.168.0.4/post-install.sh -o /tmp/post-install.sh; /usr/bin/curl tftp://192.168.0.4/secrets.sh -o /tmp/secrets.sh; bash /tmp/post-install.sh"
```
