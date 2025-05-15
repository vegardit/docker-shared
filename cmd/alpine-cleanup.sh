#!/bin/sh
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-shared

set -e

echo "#################################################"
echo "Removing logs, caches and temp files..."
echo "#################################################"
rm -rf \
   /tmp/* \
   /var/cache/apk/* \
   /var/tmp/*
