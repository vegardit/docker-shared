#!/usr/bin/env bash
#
# Copyright 2021-2022 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#

source $(dirname $0)/../lib/bash-init.sh

echo "#################################################"
echo "apt-get clean up..."
echo "#################################################"
apt-get remove apt-utils -y
apt-get clean autoclean
apt-get autoremove --purge -y

echo "#################################################"
echo "Removing logs, caches and temp files..."
echo "#################################################"
rm -rf /var/cache/{apt,debconf} \
   /var/lib/apt/lists/* \
   /var/log/{apt,alternatives.log,bootstrap.log,dpkg.log} \
   /tmp/* /var/tmp/*
