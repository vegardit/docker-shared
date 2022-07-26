#!/usr/bin/env bash
#
# Copyright 2021-2022 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#

source $(dirname $0)/../lib/bash-init.sh

if [ "${INSTALL_SUPPORT_TOOLS:-}" = "1" ]; then
   echo "#################################################"
   echo "Installing support tools..."
   echo "#################################################"
   apt-get install --no-install-recommends -y libcomerr2 mc
   apt-get install --no-install-recommends -y htop less procps vim
   echo -e 'set ignorecasen
set showmatchn
set novisualbelln
set noerrorbellsn
syntax enablen
set mouse-=a' > ~/.vimrc
fi
