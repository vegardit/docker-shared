#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-shared

# shellcheck source=SCRIPTDIR/bash-init.sh
source "$(dirname "${BASH_SOURCE[0]}")/bash-init.sh"

#################################################
# determine directory of current script
#################################################
project_root=$(readlink -e "$(dirname "$0")")
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
  local rc
  rc=$?
  if [[ ! $rc -eq 0 ]]; then
    exit $rc
  fi

  #################################################
  # remove untagged images
  #################################################
  # http://www.projectatomic.io/blog/2015/07/what-are-docker-none-none-images/
  docker images -f dangling=true -q --no-trunc | xargs -r docker rmi || true

  #################################################
  # display some image information
  #################################################
  if [[ -n ${image_name:-} && -n ${image_repo:-} ]]; then
    echo ""
    echo "IMAGE NAME"
    # shellcheck disable=SC2154  # image_name is referenced but not assigned.
    echo "$image_name"
    echo ""
    # shellcheck disable=SC2154  # image_repo is referenced but not assigned.
    docker images "$image_repo"
    echo ""
    # shellcheck disable=SC2154  # image_name is referenced but not assigned.
    docker history "$image_name"
  fi
}
add_trap _on_exit EXIT


#################################################
# reusable functions
#################################################

# start_docker_registry - Launch a local Docker registry on a free port and export its address
#
# Usage:
#   start_docker_registry <ENV_VAR_NAME>
#
# Description:
#   Starts a Docker registry container on the first free port between 5000–6000.
#   Waits for it to become reachable, then exports its address (e.g. 127.0.0.1:5001)
#   to the specified environment variable. Also sets a companion variable
#   <ENV_VAR_NAME>_CONTAINER_NAME with the container name and registers a trap
#   to stop the container on EXIT.
#
# Example:
#   start_docker_registry LOCAL_REGISTRY
#   curl http://$LOCAL_REGISTRY/v2/
function start_docker_registry() {
  local result_env_var=$1
  local local_registry
  local local_registry_container_name
  local port

  for port in {5000..6000}; do
    if ! lsof -iTCP:"$port" -sTCP:LISTEN -t >/dev/null; then
      local_registry_container_name="local-registry-$port"
      (set -x; docker run -d --rm -p "$port:5000" --name "$local_registry_container_name" ghcr.io/dockerhub-mirror/registry)
      local_registry="127.0.0.1:$port"

      add_trap "docker stop '${local_registry_container_name}'" EXIT

      log INFO "Waiting for Docker registry [http://$local_registry/v2/] to be ready..."
      if ! curl --fail --silent --show-error \
                --max-time 1 \
                --retry 10 \
                --retry-all-errors \
                --retry-delay 1 \
                --retry-max-time 10 \
                "http://$local_registry/v2/"; then
        echo "❌ Docker registry failed to start" >&2
        return 1
      fi
      log INFO "✅ Registry is ready."
      break
    fi
  done
  if [[ -z "${local_registry:-}" ]]; then
    echo "❌ No free TCP port between 5000–6000" >&2
    return 1
  fi

  # assign to the dynamic variable and export it
  eval "$result_env_var=\"$local_registry\""
  # shellcheck disable=SC2163  # This does not export 'result_env_var'. Remove $/${} for that, or use ${var?} to quiet.
  export "$result_env_var"
  echo "$result_env_var=$local_registry"

  eval "${result_env_var}_CONTAINER_NAME=\"$local_registry_container_name\""
  export "${result_env_var}_CONTAINER_NAME"
  echo "${result_env_var}_CONTAINER_NAME=$local_registry_container_name"
}
