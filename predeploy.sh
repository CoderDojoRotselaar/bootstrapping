#!/bin/bash

curl -sSL https://raw.githubusercontent.com/CoderDojoRotselaar/bootstrapping/master/deploy.sh \
  >/usr/local/sbin/deploy.sh
chmod a+x /usr/local/sbin/deploy.sh

cat <<EOF >/etc/systemd/system/auto-deploy.service
[Unit]
Description=predeploy script
ConditionPathExists=/.deploy

[Service]
Type=oneshot
Environment=HOME=/root
Environment=USER=root
ExecStart=/usr/local/sbin/deploy.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable auto-deploy
mkdir /.deploy
