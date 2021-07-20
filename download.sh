#!/usr/bin/env bash
#
# Copyright 2019-2021 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#

set -eu

#################################################
# argument parsing
#################################################
if [ "$#" -ne 2 ]; then
   echo "Usage: $0 GITHUB_BRANCH INSTALL_DIRECTORY" >&2
   echo
   echo "Examples:"
   echo " $ $0 v1 ./.shared"
   echo " $ curl -sSf https://raw.githubusercontent.com/vegardit/docker-shared/v1/download.sh?_=\$(date +%s) | bash -s v1 ./.shared"
   exit 1
fi

branch=$1
install_dir=$2

if [ -e "$install_dir" ]; then
   if [ -f "$install_dir" ]; then
      echo "ERROR: Target path [$install_dir] already exists and is a file!"
      exit 1
   fi
   if [ -n "$(ls -A '$install_dir')" ]; then
      echo "ERROR: Target directory [$install_dir] already exists and is not empty!"
      exit 1
   fi
fi


#################################################
# download
#################################################
echo "INFO: Downloading [github.com/vegardit/docker-shared@$branch] into [$install_dir]..."

#curl + tar is faster
#git clone --depth 1 --single-branch --branch $branch https://github.com/vegardit/docker-shared/ $install_dir
mkdir -p "$install_dir"
curl -fsS https://codeload.github.com/vegardit/docker-shared/tar.gz/refs/heads/$branch | tar xz -C "$install_dir" --strip-components 1


#################################################
# ensure Linux new line chars
#################################################
# check if dos2unix command is abailable
if command -v dos2unix >/dev/null; then
   # env -i PATH="$PATH" -> workaround for "find: The environment is too large for exec()"
   env -i PATH="$PATH" find "$install_dir" -type f -name '*.sh' -exec bash -c "dos2unix < '{}' | cmp --silent '{}' - || dos2unix '{}'" \;
fi

#################################################
# ensure scripts are executable
#################################################
env -i PATH="$PATH" find "$install_dir" -type f -name '*.sh' -exec chmod 555 {} \;
