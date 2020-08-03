#!/bin/bash

wget https://raw.githubusercontent.com/CoderDojoRotselaar/bootstrapping/master/predeploy.sh -O /tmp/predeploy.sh
bash /tmp/predeploy.sh

if [[ -f "/tmp/secrets.sh" ]]; then
  bash /tmp/secrets.sh
fi
