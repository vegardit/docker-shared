#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-shared

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
