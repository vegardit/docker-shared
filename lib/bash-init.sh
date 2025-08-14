#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: © Vegard IT GmbH (https://vegardit.com)
# SPDX-FileContributor: Sebastian Thomschke
# SPDX-License-Identifier: Apache-2.0
# SPDX-ArtifactOfProjectHomePage: https://github.com/vegardit/docker-shared

set -eu

#################################################
# execute script with bash if loaded with other shell interpreter
#################################################
if [ -z "${BASH_VERSINFO:-}" ]; then /usr/bin/env bash "$0" "$@"; exit; fi

set -o pipefail


#################################################
# core functions
#################################################

# log - structured logger for stdout/stderr or piped input
#
# Usage:
#   log BOX "Initializing system..."
#   log INFO "This is an info message"
#   log WARN "Log file is missing"
#   log ERROR "Something went wrong"
#   echo "message" | log INFO
#   the_command 2> >(log ERROR >&2) | log INFO
function log() {
  local level=${1:-INFO}
  level=${level^^}
  shift

  case $level in
    BOX)             local display_level=INFO ;;
    INFO|WARN|ERROR) local display_level=$level ;;
    *) log ERROR "Unsupported log-level $level"; exit 1 ;;
  esac

  local prefix
  prefix="$(date "+%Y-%m-%d %H:%M:%S") $display_level [${BASH_SOURCE[1]}:${BASH_LINENO[0]}]"

  if [[ $level == BOX ]]; then
    # Use Unicode box drawing unless NO_UNICODE is set
    local h_line v_line tl tr bl br
    if [[ -n ${NO_UNICODE:-} ]]; then
      h_line='-'; v_line='|'; tl='+'; tr='+'; bl='+'; br='+'
    else
      h_line='─'; v_line='│'; tl='┌'; tr='┐'; bl='└'; br='┘'
    fi

    # Read boxed text
    local text="$*"
    if [[ -z $text ]]; then
      IFS= read -r text || return
    fi

    # Support multi-line messages
    local line lines maxlen=0
    IFS=$'\n' read -rd '' -a lines <<<"$text" || true
    for line in "${lines[@]}"; do
      (( ${#line} > maxlen )) && maxlen=${#line}
    done
    (( maxlen < 40 )) && maxlen=40

    printf '%s %s\n' "$prefix" "$tl$(printf '%*s' $((maxlen + 2)) '' | tr ' ' "$h_line")$tr"
    for line in "${lines[@]}"; do
      printf '%s %s %-*s %s\n' "$prefix" "$v_line" "$maxlen" "$line" "$v_line"
    done
    printf '%s %s\n' "$prefix" "$bl$(printf '%*s' $((maxlen + 2)) '' | tr ' ' "$h_line")$br"
  elif (( $# )); then
    printf '%s %s\n' "$prefix" "$*"
  else
    while IFS= read -r line; do
      printf '%s %s\n' "$prefix" "$line"
    done
  fi
}


# add_trap - append a command to a signal trap without overwriting it
#
# Usage: add_trap "command" [SIGNAL]
#   command - string to evaluate when SIGNAL triggers
#   SIGNAL  - name or number (default: EXIT)
#
# Examples:
#   add_trap 'echo goodbye'      # appends to EXIT
#   add_trap 'echo SIGINT!' INT
#
# Skips duplicate registrations for the same command+signal combo.
function add_trap() {
  local cmd=$1
  local sig=${2:-EXIT}

  local sig_name
  {
    if [[ $sig =~ ^[0-9]+$ ]]; then
      sig_name=$(kill -l "$sig")
    else
      sig_name=${sig^^}
      kill -l "$sig_name" &>/dev/null
    fi
  } || {
    log ERROR "add_trap: invalid signal '$sig'"
    return 1
  }

  # Compute effective trap list for current (sub)shell
  # Based on info from https://stackoverflow.com/a/59307894/5116073
  local old
  if [[ "${BASH_VERSINFO:-0}" -ge 4 ]]; then
    trap -- KILL &>/dev/null || true
    old=$(trap -p "$sig_name")
  else
    old=$( (trap -p "$sig_name") )
  fi
  old=${old#*\'}         # remove leading "trap -- '"
  old=${old%\'*}         # remove trailing "' EXIT"
  old=${old//"'\''"/"'"} # unescape every '\'' to '

  # if already present, do nothing
  if [[ ";$old;" == *";$cmd;"* ]]; then
    return 0
  fi

  # build the new combined handler
  if [[ -n $old ]]; then
    combined="$old;$cmd"
  else
    combined="$cmd"
  fi

  # check if debugging requested *and* xtrace wasn't already on
  if [[ ${ADD_TRAP_DEBUG:-} =~ ^(1|true)$ && $- != *x* ]]; then
    set -x
    trap -- "$combined" "$sig"
    set +x
  else
    trap -- "$combined" "$sig"
  fi
}


# interpolate - pure Bash alternative to `envsubst` for basic variable expansion
#
# Usage:
#   interpolated=$(interpolate < template.file)
#
# Based on https://stackoverflow.com/a/40167919
function interpolate() {
  # Bash based envsubst (https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html)
  local line lineEscaped
  while IFS= read -r line || [ -n "$line" ]; do  # the `||` clause ensures that the last line is read even if it doesn't end with \n
    # escape all chars that could trigger an expansion
    IFS= read -r lineEscaped < <(echo "$line" | tr '`([$' '\1\2\3\4')
    # selectively re-enable ${ references
    lineEscaped=${lineEscaped//$'\4'{/\${}
    # escape back slashes to preserve them
    lineEscaped=${lineEscaped//\\/\\\\}
    # escape embedded double quotes to preserve them
    lineEscaped=${lineEscaped//\"/\\\"}
    eval "printf '%s\n' \"$lineEscaped\"" | tr '\1\2\3\4' '`([$'
  done
}


#################################################
# configure logging/error reporting
#################################################
set -o errtrace

# shellcheck disable=SC2016   # Expressions don't expand in single quotes
add_trap 'rc=$?; echo >&2 "$(date +%H:%M:%S) Error - exited with status $rc in [$BASH_SOURCE] at line $LINENO:"; cat -n $BASH_SOURCE | tail -n+$((LINENO - 3)) | head -n7' ERR

# if TRACE_SCRIPTS=1 or  TRACE_SCRIPTS contains a glob pattern that matches $0
if [[ ${TRACE_SCRIPTS:-} == "1" || ${TRACE_SCRIPTS:-} == "$0" ]]; then
  if [[ $- =~ x ]]; then
    # "set -x" was specified already, we only improve the PS4 in this case
    PS4='+\033[90m[$?] $BASH_SOURCE:$LINENO ${FUNCNAME[0]}()\033[0m '
  else
    # "set -x" was not specified, we use a DEBUG trap for better debug output
    set -o functrace

    __trace() {
      if [[ ${FUNCNAME[1]} == "log" && ${BASH_SOURCE[1]} == "${BASH_SOURCE[0]}" ]]; then
        # don't log internals of log() function
        return
      fi
      printf "\e[90m#[$?] ${BASH_SOURCE[1]}:$1 ${FUNCNAME[1]}() %*s\e[35m%s\e[m\n" "$(( 2 * (BASH_SUBSHELL + ${#FUNCNAME[*]} - 2) ))" "$BASH_COMMAND" >&2
    }

    # shellcheck disable=SC2016   # Expressions don't expand in single quotes
    add_trap '__trace $LINENO' DEBUG
  fi
fi
