#!/usr/bin/env bash
#
# Copyright 2019-2021 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#

source $(dirname $0)/../lib/bash-init.sh

echo "#################################################"
echo "Installing latest OS updates..."
echo "#################################################"
apt-get update -y
# https://github.com/phusion/baseimage-docker/issues/319
apt-get install --no-install-recommends -y apt-utils 2> >( grep -v 'debconf: delaying package configuration, since apt-utils is not installed' >&2 )
apt-get upgrade -y
