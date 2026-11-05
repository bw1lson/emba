#!/usr/bin/env bats

# EMBA - EMBEDDED LINUX ANALYZER
#
# Copyright 2026-2026 Siemens Energy AG
#
# EMBA comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
# welcome to redistribute it under the terms of the GNU General Public License.
# See LICENSE file for usage of this software.
#
# EMBA is licensed under GPLv3
# SPDX-License-Identifier: GPL-3.0-only
#

load ../setup.bash

setup() {
  setup_emba_test_env
  # shellcheck source=/dev/null
  source "${MOD_DIR}/P56_ofrak_extractor.sh"
  # shellcheck source=/dev/null
  source "${INVOCATION_PATH}/installer/IP62_ofrak.sh"
  export EXT_DIR="${LOG_DIR}/external"
  export FIRMWARE_PATH_BAK="${TMP_DIR}/firmware image.bin"
  export LOG_PATH_MODULE="${LOG_DIR}/p56_ofrak_extractor"
  export HOME_PATH="${LOG_DIR}"
  export LIST_DEP=0 IN_DOCKER=1 DOCKER_SETUP=0 FULL=0
  export UEFI_VERIFIED=0 DISABLE_DEEP=0
  export OFRAK_MISSING=0 OFRAK_RESULT=success OFRAK_BACKEND_STATUS=0
  export OFRAK_ACCEPT_COMMUNITY_LICENSE=0 OFRAK_APT_STATUS=0
  export INSTALL_APP_LIST=()
  mkdir -p "${LOG_PATH_MODULE}"
  printf 'firmware' >"${FIRMWARE_PATH_BAK}"

  module_log_init() { :; }
  module_title() { :; }
  pre_module_reporter() { :; }
  module_end_log() { printf '%s\n' "$2" >"${TMP_DIR}/module_end"; }
  print_output() { printf '%s\n' "$1" >>"${LOG_FILE}"; }
  write_csv_log() { printf '%s;%s\n' "$1" "$2" >>"${CSV_DIR}/p56.csv"; }
  remove_uprintable_paths() { printf 'cleanup\n' >>"${TMP_DIR}/events"; }
  populate_p99_backend() {
    cp "$1" "${TMP_DIR}/indexed.list"
    printf '%s;%s\n' "$2" "$3" >"${TMP_DIR}/backend"
    printf 'backend\n' >>"${TMP_DIR}/events"
    return "${OFRAK_BACKEND_STATUS}"
  }
  linux_basic_identification() { printf '0\n'; }
  detect_root_dir_helper() {
    printf '%s\n' "$1" >"${TMP_DIR}/roots"
    printf 'roots\n' >>"${TMP_DIR}/events"
  }
  command() {
    if [[ "${1:-}" == "-v" && "${2:-}" == "${EXT_DIR}/ofrak_venv/bin/ofrak" ]]; then
      [[ "${OFRAK_MISSING}" -eq 0 ]]
    else
      builtin command "$@"
    fi
  }
  timeout() {
    printf '%s\n' "$@" >"${TMP_DIR}/arguments"
    printf '%s\n' "${PATH}" >"${TMP_DIR}/ofrak_path"
    local lOUTPUT_DIR=""
    while [[ "$#" -gt 0 ]]; do
      if [[ "$1" == "-o" ]]; then
        lOUTPUT_DIR="$2"
        break
      fi
      shift
    done
    [[ -n "${lOUTPUT_DIR}" ]] || return 1
    if [[ "${OFRAK_RESULT}" == "empty" ]]; then
      return
    fi
    mkdir -p "${lOUTPUT_DIR}/root.ofrak_children/etc.ofrak_children"
    printf 'unpacked' >"${lOUTPUT_DIR}/root.ofrak_children/etc.ofrak_children/passwd"
    printf 'resource tree' >"${lOUTPUT_DIR}/__ofrak_info__"
    printf 'OFRAK console output\n'
    if [[ "${OFRAK_RESULT}" == "failure" ]]; then
      printf 'OFRAK component failed\n' >&2
      return 23
    fi
  }
  print_tool_info() { INSTALL_APP_LIST+=("$1"); }
  print_pip_info() { :; }
  apt-get() {
    printf '%s\n' "$@" >"${TMP_DIR}/apt_arguments"
    return "${OFRAK_APT_STATUS}"
  }
  create_pipenv() {
    mkdir -p "$1/bin"
    ln -s /bin/echo "$1/bin/python3"
    ln -s /bin/echo "$1/bin/ofrak"
  }
}

teardown() {
  teardown_emba_test_env
}

@test "P56 publishes OFRAK artifacts through the backend before root detection" {
  P56_ofrak_extractor

  [[ "$(<"${TMP_DIR}/backend")" == "P56_ofrak_extractor;1" ]]
  [[ "$(<"${TMP_DIR}/roots")" == "${LOG_DIR}/firmware" ]]
  [[ "${FIRMWARE_PATH}" == "${LOG_DIR}/firmware" ]]
  [[ "$(<"${TMP_DIR}/module_end")" -eq 1 ]]
  [[ "$(<"${TMP_DIR}/events")" == $'cleanup\nbackend\nroots' ]]
  [[ "$(<"${TMP_DIR}/ofrak_path")" == "${EXT_DIR}/ofrak_venv/bin:"* ]]
  grep -Fxq -- "--recursive" "${TMP_DIR}/arguments"
  grep -Fxq -- "--exclude-components-missing-dependencies" "${TMP_DIR}/arguments"
  grep -Fxq -- "${FIRMWARE_PATH_BAK}" "${TMP_DIR}/arguments"
  grep -Fxq -- "${EXT_DIR}/ofrak_venv/bin/ofrak" "${TMP_DIR}/arguments"
  [[ ! -f "${LOG_DIR}/firmware/ofrak_extracted/__ofrak_info__" ]]
  grep -q 'OFRAK console output' "${LOG_PATH_MODULE}"/*.log
  grep -q 'resource tree' "${LOG_PATH_MODULE}"/*.info
  [[ "$(tr -cd '\0' <"${TMP_DIR}/indexed.list" | wc -c)" -eq 1 ]]
}

@test "P56 reports extraction failure and still publishes partial artifacts" {
  export OFRAK_RESULT=failure
  P56_ofrak_extractor

  [[ "$(<"${TMP_DIR}/module_end")" -eq 1 ]]
  [[ -f "${TMP_DIR}/indexed.list" ]]
  grep -q 'exit 23' "${LOG_FILE}"
  grep -q 'OFRAK component failed' "${LOG_PATH_MODULE}"/*.log
}

@test "P56 does not run for verified UEFI Linux or disabled extraction" {
  local lSETTING=""
  for lSETTING in UEFI_VERIFIED RTOS DISABLE_DEEP; do
    export UEFI_VERIFIED=0 RTOS=1 DISABLE_DEEP=0
    if [[ "${lSETTING}" == "RTOS" ]]; then
      export RTOS=0
    else
      export "${lSETTING}=1"
    fi
    P56_ofrak_extractor
    [[ "$(<"${TMP_DIR}/module_end")" -eq 0 ]]
    [[ ! -f "${TMP_DIR}/arguments" ]]
  done
}

@test "P56 skips directory input and an unavailable OFRAK executable" {
  export FIRMWARE_PATH_BAK="${TMP_DIR}"
  P56_ofrak_extractor
  [[ ! -f "${TMP_DIR}/arguments" ]]
  [[ "$(<"${TMP_DIR}/module_end")" -eq 0 ]]

  export FIRMWARE_PATH_BAK="${TMP_DIR}/firmware image.bin" OFRAK_MISSING=1
  P56_ofrak_extractor
  [[ ! -f "${TMP_DIR}/arguments" ]]
  [[ "$(<"${TMP_DIR}/module_end")" -eq 0 ]]
  grep -q 'OFRAK is not installed' "${LOG_FILE}"
}

@test "P56 leaves existing root detection untouched when nothing is extracted" {
  export OFRAK_RESULT=empty
  P56_ofrak_extractor

  [[ "$(<"${TMP_DIR}/module_end")" -eq 0 ]]
  [[ ! -f "${TMP_DIR}/backend" ]]
  [[ ! -f "${TMP_DIR}/roots" ]]
}

@test "P56 propagates backend failure without reporting module success" {
  export OFRAK_BACKEND_STATUS=27
  run P56_ofrak_extractor

  [[ "${status}" -eq 27 ]]
  [[ ! -f "${TMP_DIR}/roots" ]]
  [[ ! -f "${TMP_DIR}/module_end" ]]
}

@test "OFRAK helper retains nonempty output instead of invoking a no-op unpack" {
  local lOUTPUT_DIR="${LOG_DIR}/firmware/ofrak_extracted"
  mkdir -p "${lOUTPUT_DIR}"
  printf 'previous' >"${lOUTPUT_DIR}/previous.bin"

  run ofrak_extractor "${FIRMWARE_PATH_BAK}" "${lOUTPUT_DIR}"

  [[ "${status}" -eq 1 ]]
  [[ "$(<"${lOUTPUT_DIR}/previous.bin")" == "previous" ]]
  [[ ! -f "${TMP_DIR}/arguments" ]]
  grep -q 'retaining existing artifacts' "${LOG_FILE}"
}

@test "OFRAK installer pins an isolated installation without accepting a license by default" {
  run IP62_ofrak

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"-m pip install ofrak==3.2.0"* ]]
  [[ "${output}" == *"configure an appropriate license"* ]]
  [[ "${output}" != *"license --community --i-agree"* ]]
  [[ -L "${EXT_DIR}/ofrak_venv/bin/python3" ]]
}

@test "OFRAK installer automates Community acceptance only with explicit opt-in" {
  export OFRAK_ACCEPT_COMMUNITY_LICENSE=1
  run IP62_ofrak

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"license --community --i-agree"* ]]
  [[ "${output}" == *"Community License accepted"* ]]
}

@test "OFRAK dependency listing and Docker host setup do not install or accept licenses" {
  export LIST_DEP=1 OFRAK_ACCEPT_COMMUNITY_LICENSE=1
  IP62_ofrak
  [[ ! -e "${EXT_DIR}/ofrak_venv" ]]
  [[ ! -f "${TMP_DIR}/apt_arguments" ]]

  export LIST_DEP=0 IN_DOCKER=0 DOCKER_SETUP=1
  IP62_ofrak
  [[ ! -e "${EXT_DIR}/ofrak_venv" ]]
  [[ ! -f "${TMP_DIR}/apt_arguments" ]]
}

@test "OFRAK installer stops when system dependency installation fails" {
  export OFRAK_APT_STATUS=19
  run IP62_ofrak

  [[ "${status}" -eq 19 ]]
  [[ ! -e "${EXT_DIR}/ofrak_venv" ]]
  [[ "${output}" != *"Community License accepted"* ]]
}
