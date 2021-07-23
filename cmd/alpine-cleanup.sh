#!/bin/sh
#
# Copyright 2019-2021 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#
set -e

echo "#################################################"
echo "Removing logs, caches and temp files..."
echo "#################################################"
rm -rf \
   /tmp/* \
   /var/cache/apk/* \
   /var/tmp/*
