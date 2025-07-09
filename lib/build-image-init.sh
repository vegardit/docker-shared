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
if command -v dos2unix >/dev/null; then
  # env -i PATH="$PATH" -> workaround for "find: The environment is too large for exec()"
  env -i PATH="$PATH" find "$project_root" -type f -name '*.sh' -exec bash -c "dos2unix < '{}' | cmp --silent '{}' - || dos2unix '{}'" \;
fi


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

# run_step - execute a command and wrap its output in a titled section
#
# Usage:
#   run_step [<title> --] <command> [args...]
#   run_step [<title>] @@ <raw-shell-string>
#
# If <title> is omitted, the full command line (or raw string) becomes the title.
#
# Modes:
#   --  safe: each argument is shell-escaped
#   @@  raw: eval the entire string (pipes, redirects, etc.)
#
# On GitHub Actions (GITHUB_ACTIONS=true):
#   ::group::<title>
#     ...traced output..
#   ::endgroup::
#
# Otherwise: prints box delimiters
run_step() {
  local -a args
  args=("$@")

  # Need at least one argument
  (( ${#args[@]} )) || {
    log ERROR "Usage: run_step [<title> --] <cmd> [args...] | [<title>] @@ <raw-shell-string>"
    return 2
  }

  local cmd title
  if [[ ${args[0]} == '@@' ]]; then
    (( ${#args[@]} > 1 )) || {
      log ERROR "Usage: run_step @@ <raw-shell-string>"
      return 2
    }
    cmd=${args[1]}
    title=$cmd
  elif (( ${#args[@]} > 1 )) && [[ ${args[1]} == '@@' ]]; then
   (( ${#args[@]} > 2 )) || {
     log ERROR "Usage: run_step <title> @@ <raw-shell-string>"
     return 2
   }
    title=${args[0]}
    cmd=${args[2]}
  else
    # Parse title and cmd
    local -a cmd_parts
    cmd_parts=()
    if [[ ${args[0]} == -- ]]; then
      title="${args[*]:1}"
      cmd_parts=( "${args[@]:1}" )
    elif (( ${#args[@]} > 1 )) && [[ ${args[1]} == -- ]]; then
      title=${args[0]}
      cmd_parts=( "${args[@]:2}" )
    else
      cmd_parts=( "${args[@]}" )
      title=${args[*]}
    fi

    # Must have a command to run
    (( ${#cmd_parts[@]} )) || {
      log ERROR "Usage: run_step [<title> --] <cmd> [args...] | [<title>] @@ <raw-shell-string>"
      return 2
    }

    # Build the eval-safe command string
    local part
    for part in "${cmd_parts[@]}"; do
      cmd+=" $(printf '%q' "$part")"
    done
    cmd=${cmd# }  # strip the leading space
  fi

  # Header
  if [[ ${GITHUB_ACTIONS:-} == "true" && -z ${ACT:-} ]]; then
    printf '::group::%s\n' "$title"
  else
    # need to color each line separately for nektos/act
    printf '\033[95m═══════════════════════════════════════════════════════════\033[0m\n'
    printf '\033[95m│ %s...\033[0m\n' "$title"
    printf '\033[95m───────────────────────────────────────────────────────────\033[0m\n'
  fi

  # Execute command with tracing
  local rc
  printf '\033[90m+ %s:%d:\033[0;1m %s\033[0m\n'  "${BASH_SOURCE[1]}" "${BASH_LINENO[0]}" "$cmd"
  eval -- "$cmd"
  rc=$?

  # Footer
  if [[ ${GITHUB_ACTIONS:-} == "true" && -z ${ACT:-} ]]; then
    echo "::endgroup::"
  else
    printf '\033[92m───────────────────────────────────────────────────────────\033[0m\n'
    printf '\033[92m│ %s ✓\033[0m\n' "$title"
    printf '\033[92m═══════════════════════════════════════════════════════════\033[0m\n'
  fi

  return $rc
}


# curl_with_retry – Invoke curl with sane defaults unless overridden by caller
#
# Usage:
#   curl_with_retry [curl_options] <url> [...]
#
# Examples:
#   # Use all the defaults
#   curl_with_retry https://example.com/data.json
#
#   # Override just the max-time (don't use the default of 30s)
#   curl_with_retry --max-time 60 https://example.com/data.json
#
#   # Disable retries entirely by explicitly setting --retry 0
#   curl_with_retry --retry 0 https://example.com/data.json
curl_with_retry() {
  local args=("$@")

  [[ $* != *"--connect-timeout"* ]] && args=(--connect-timeout 10 "${args[@]}")
  [[ $* != *"--max-time"*        ]] && args=(--max-time 30        "${args[@]}")
  [[ $* != *"--retry"*           ]] && args=(--retry 3            "${args[@]}")

  command curl -sSfL --retry-all-errors "${args[@]}"
}


# start_docker_registry - Launch a local Docker registry and export its address
#
# Usage:
#   start_docker_registry <ENV_VAR_NAME>
#
# Description:
#   Starts a Docker registry container with automatic host-port mapping.
#   Waits for the registry at `http://127.0.0.1:<port>/v2/` to become ready,
#   then exports:
#     <ENV_VAR_NAME>               – registry endpoint (host:port, e.g. 127.0.0.1:32768)
#     <ENV_VAR_NAME>_CONTAINER_ID  – container ID
#     <ENV_VAR_NAME>_CONTAINER_NAME– container name
#   Registers a trap to stop the registry on script EXIT.
#
# Example:
#   start_docker_registry LOCAL_REGISTRY
#   curl http://$LOCAL_REGISTRY/v2/
function start_docker_registry() {
  local result_env_var=$1

  # Detect whether *this* script is running in a container
  if ! grep -Eq '(docker|kubepods|containerd|actions_job)' <(head -n1 /proc/1/cgroup); then
    local run_args="-P" # we’re on a host VM -> publish random host port
  fi

  # Launch the registry with an automatic host port
  local container_id
  # shellcheck disable=SC2086  # Double quote to prevent globbing and word
  container_id=$(docker run -d --rm ${run_args:-} ghcr.io/dockerhub-mirror/registry)
  if [[ -z $container_id ]]; then
    echo "❌ Failed to start registry container" >&2
    return 1
  fi
  add_trap "docker stop '$container_id'" EXIT

  local host port
  if [[ -z ${run_args:-} ]]; then
    # --- inside a container (e.g. act_runner): use container IP + fixed port 5000
    host=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_id")
    port=5000
  else
    # --- outside: discover the random host port that Docker published
    for _ in {1..10}; do
      port=$(docker inspect --format='{{ (index (index .NetworkSettings.Ports "5000/tcp") 0).HostPort }}' "$container_id")
      [[ -n $port ]] && break
      sleep 0.2
    done
    if [[ -z $port ]]; then
      echo "❌ Could not determine host port for registry" >&2
      docker stop "$container_id"
      return 1
    fi
    host=127.0.0.1
  fi

  # Wait for the registry to become reachable
  local local_registry="$host:$port"
  local local_registry_url="http://$local_registry/v2/"
  log INFO "Waiting for Docker registry [$local_registry_url] to be ready..."
  if ! curl_with_retry \
            --max-time 1 \
            --retry 10 \
            --retry-delay 1 \
            --retry-max-time 10 \
            "$local_registry_url"; then
    echo "❌ Docker registry failed to start" >&2
    docker stop "$container_id"
    return 1
  fi
  log INFO "✅ Registry is ready."

  # Export variables
  export "$result_env_var"="$local_registry"
  echo "$result_env_var=$local_registry"

  export "${result_env_var}_CONTAINER_ID"="$container_id"
  echo "${result_env_var}_CONTAINER_ID=$container_id"

  local container_name
  container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's|^/||')
  export "${result_env_var}_CONTAINER_NAME"="$container_name"
  echo "${result_env_var}_CONTAINER_NAME=$container_name"
}
