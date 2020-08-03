#!/bin/bash

mkdir -p /root/.ssh
chmod 700 /root/.ssh

base64 -d <<EOF >/root/.ssh/coderdojo-crypt-key
*** the git crypt key in base64 encoding ***
EOF

chmod 600 /root/.ssh/coderdojo-crypt-key