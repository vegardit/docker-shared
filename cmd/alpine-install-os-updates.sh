#!/bin/sh
#
# Copyright 2019-2021 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#

echo "#################################################"
echo "Installing latest OS updates..."
echo "#################################################"
apk --no-cache -U upgrade
