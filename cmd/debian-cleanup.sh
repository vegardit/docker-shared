#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-shared

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
