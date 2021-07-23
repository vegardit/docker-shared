#!/usr/bin/env bash
#
# Copyright 2019-2021 by Vegard IT GmbH, Germany, https://vegardit.com
# SPDX-License-Identifier: Apache-2.0
#
# Author: Sebastian Thomschke, Vegard IT GmbH
#

source $(dirname ${BASH_SOURCE[0]})/bash-init.sh

#################################################
# determine directory of current script
#################################################
project_root=$(readlink -e $(dirname "$0"))
echo "project_root=$project_root"


#################################################
# ensure Linux new line chars
#################################################
# env -i PATH="$PATH" -> workaround for "find: The environment is too large for exec()"
env -i PATH="$PATH" find "$project_root" -type f -name '*.sh' -exec bash -c "dos2unix < '{}' | cmp --silent '{}' - || dos2unix '{}'" \;


#################################################
# calculate BASE_LAYER_CACHE_KEY
#################################################
# using the current date, i.e. the base layer cache (that holds system packages with security updates) will be invalidate once per day
base_layer_cache_key=$(date +%Y%m%d)
echo "base_layer_cache_key=$base_layer_cache_key"


#################################################
# register exit callback
#################################################
function _on_exit() {
   rc=$?
   if [[ ! $rc -eq 0 ]]; then
      exit $rc
   fi

   #################################################
   # remove untagged images
   #################################################
   # http://www.projectatomic.io/blog/2015/07/what-are-docker-none-none-images/
   untagged_images=$(docker images -f "dangling=true" -q --no-trunc)
   [[ -n $untagged_images ]] && docker rmi $untagged_images || true

   #################################################
   # display some image information
   #################################################
   echo ""
   echo "IMAGE NAME"
   echo "$image_name"
   echo ""
   docker images "$image_repo"
   echo ""
   docker history "$image_name"
}
trap _on_exit EXIT
