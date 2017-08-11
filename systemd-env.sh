#!/usr/bin/env bash

set -o errexit -o nounset -o pipefail

# recursive `env -i exec` to clean the env
if [ -z "${CLEAN_ENV:-}" ]; then
  exec /usr/bin/env -i CLEAN_ENV=1 /bin/bash "$0" "$@"
fi
unset CLEAN_ENV

OLD_ENV="$(env | sort)"

UNIT_NAME="${1}"
shift

if [ "$#" -gt 0 ]; then
  CMD="$@"
fi

# Validate systemd unit name
if ! systemctl is-active -q "${UNIT_NAME}"; then
  echo >&2 "ERROR: systemd unit not active: ${UNIT_NAME}"
  exit 1
fi

# Use private agent config, if exists, otherwise public agent config.
UNIT_FILE="$(systemctl show -p FragmentPath ${UNIT_NAME} | cut -d'=' -f2)"
if [[ -z "${UNIT_FILE}" ]] || ! [[ -f "${UNIT_FILE}" ]]; then
  echo >&2 "ERROR: Can't find the systemd unit definition for ${UNIT_NAME}"
  exit 1
fi

# extract EnvironmentFiles from the systemd unit definition
ENV_FILES="$(grep "EnvironmentFile=" "${UNIT_FILE}" | cut -d'=' -f2)"
if [[ -z "${ENV_FILES}" ]]; then
  echo >&2 "ERROR: Can't find any EnvironmentFiles in the ${UNIT_NAME} systemd unit definition"
  echo >&2 "${UNIT_FILE}"
  echo >&2 "$(cat "${UNIT_FILE}")"
  exit 1
fi

# systemd env files are not POSIX compliant, can't be sourced :(
# https://www.freedesktop.org/software/systemd/man/systemd.exec.html#EnvironmentFile=
function systemd_source() {
  local prev_line=""
  while read -r line; do
    # empty lines, lines without an "=" separator, or lines starting with ; or # will be ignored
    if [[ "${line}" == "" ]] || ! [[ "${line}" == *"="* ]] || [[ "${line}" == ";"* ]] || [[ "${line}" == "#"* ]]; then
      continue
    fi

    # A line ending with a backslash will be concatenated with the following one, allowing multiline variable definitions.
    if [[ -n "${prev_line}" ]]; then
      line="${prev_line}${line}"
    fi
    # TODO: allow spaces after backslash?
    if [[ "${line}" == *"\\" ]]; then
      # trim trailing backslash
      prev_line="${line::-1}"
      continue
    else
      # reset line buffer
      prev_line=""
    fi

    KEY="$(echo "${line}" | cut -d'=' -f1)"
    VALUE="$(echo "${line}" | cut -d'=' -f2)"

    # trim leading whitespace
    VALUE="${VALUE##*( )}"
    # trim trailing whitespace
    VALUE="${VALUE%%*( )}"

    # the parser strips leading and trailing whitespace from the values of assignments, unless you use double quotes (").
    if [[ "${VALUE}" == '"'*'"' ]]; then
      # trim wrapping double quotes
      VALUE="${VALUE:1:-1}"
      # assume any inner double quotes are already escaped
    elif [[ "${VALUE}" == "'"*"'" ]]; then
      # trim wrapping single quotes
      # apparently systemd supports this, even tho the doc doesn't mention it... :(
      VALUE="${VALUE:1:-1}"
      # escape double quotes
      VALUE="${VALUE//\"/\\\"}"
      # TODO: should whitespace be trimmed within single quotes? it's not documented...
    else
      # escape double quotes
      VALUE="${VALUE//\"/\\\"}"
    fi

    # eval and pray it's valid syntax
    eval "export ${KEY}=\"${VALUE}\""
  done <<< "$(cat "$1")"
}

# source all the same EnvironmentFiles in the same order
while read -r line; do
  if [[ "${line}" == "-"* ]]; then
    # optional file, strip first character
    line="${line:1}"
    if [[ -f "${line}" ]]; then
      systemd_source "${line}"
    fi
  else
    # required file
    systemd_source "${line}"
  fi
done <<< "${ENV_FILES}"

# execute command in the emulated env
if [[ -n "${CMD:-}" ]]; then
  eval "$@"
  exit $?
fi

# print new env minus old env
TMP_FILE="$(mktemp -t systemd-env.XXXXX)"
trap "rm -f ${TMP_FILE}" EXIT

# print new env minus old env
env | sort > "${TMP_FILE}"
echo "${OLD_ENV}" | grep -F -x -v -f /dev/stdin "${TMP_FILE}"
