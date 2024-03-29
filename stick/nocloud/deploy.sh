#!/bin/bash

curl -sSL https://raw.githubusercontent.com/CoderDojoRotselaar/bootstrapping/master/deploy.sh \
  >/target/usr/local/sbin/deploy.sh
chmod a+x /target/usr/local/sbin/deploy.sh

cat <<EOF >/target/etc/systemd/system/auto-deploy.service
[Unit]
Description=predeploy script
Wants=network-online.target
After=network-online.target
ConditionPathExists=/.deploy

[Service]
Type=oneshot
Environment=HOME=/root
Environment=USER=root
ExecStart=/usr/local/sbin/deploy.sh

[Install]
WantedBy=multi-user.target
EOF

chroot /target systemctl daemon-reload
chroot /target systemctl enable auto-deploy
mkdir /target/.deploy
