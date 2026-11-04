#!/bin/bash -p

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
# Description:  Extracts firmware with OFRAK and registers artifacts for analysis.

export PRE_THREAD_ENA=0

P56_ofrak_extractor() {
  module_log_init "${FUNCNAME[0]}"

  if [[ "${UEFI_VERIFIED:-0}" -eq 1 || "${RTOS:-1}" -eq 0 || "${DISABLE_DEEP:-0}" -eq 1 ]]; then
    module_end_log "${FUNCNAME[0]}" 0
    return
  fi

  local lFW_PATH_OFRAK="${FIRMWARE_PATH_BAK}"
  if [[ ! -f "${lFW_PATH_OFRAK}" ]]; then
    print_output "[-] OFRAK extraction requires a firmware file."
    module_end_log "${FUNCNAME[0]}" 0
    return
  fi

  module_title "OFRAK binary firmware extractor"
  pre_module_reporter "${FUNCNAME[0]}"

  local lOUTPUT_DIR_OFRAK="${LOG_DIR}/firmware/ofrak_extracted"
  local lFILES_LIST="${TMP_DIR}/p56_extracted_files.list"
  local lFILES_COUNT=0
  local lLINUX_PATH_COUNTER=0

  if ! ofrak_extractor "${lFW_PATH_OFRAK}" "${lOUTPUT_DIR_OFRAK}"; then
    print_output "[-] Checking any partial OFRAK output for usable artifacts."
  fi

  if [[ -d "${lOUTPUT_DIR_OFRAK}" ]]; then
    remove_uprintable_paths "${lOUTPUT_DIR_OFRAK}" || return 1
    find "${lOUTPUT_DIR_OFRAK}" -type f ! -name "*.raw" ! -name "__ofrak_info__" -print0 >"${lFILES_LIST}"
    lFILES_COUNT="$(tr -cd '\0' <"${lFILES_LIST}" | wc -c)"
    lFILES_COUNT="${lFILES_COUNT//[[:space:]]/}"

    if [[ "${lFILES_COUNT}" -gt 0 ]]; then
      print_output "[*] Populating backend data for ${ORANGE}${lFILES_COUNT}${NC} OFRAK files."
      populate_p99_backend "${lFILES_LIST}" "${FUNCNAME[0]}" "${lFILES_COUNT}" || return "$?"
      export FIRMWARE_PATH="${LOG_DIR}/firmware"
      lLINUX_PATH_COUNTER=$(linux_basic_identification "${lOUTPUT_DIR_OFRAK}" "${FUNCNAME[0]}")
      detect_root_dir_helper "${LOG_DIR}/firmware"
    fi
  fi

  print_output "[*] Found ${ORANGE}${lFILES_COUNT}${NC} files in OFRAK output."
  write_csv_log "FILES OFRAK" "LINUX_PATH_COUNTER OFRAK"
  write_csv_log "${lFILES_COUNT}" "${lLINUX_PATH_COUNTER}"
  module_end_log "${FUNCNAME[0]}" "${lFILES_COUNT}"
}

ofrak_extractor() {
  local lFIRMWARE_PATH="${1:-}"
  local lOUTPUT_DIR_OFRAK="${2:-}"
  local lOFRAK_BIN="${EXT_DIR}/ofrak_venv/bin/ofrak"
  local lOFRAK_LOG="${LOG_PATH_MODULE}/ofrak_${RANDOM}.log"
  local lSTATUS=0

  if ! command -v "${lOFRAK_BIN}" >/dev/null; then
    print_output "[-] OFRAK is not installed - check your installation."
    return 1
  fi
  if [[ ! -f "${lFIRMWARE_PATH}" || -z "${lOUTPUT_DIR_OFRAK}" ]]; then
    print_output "[-] OFRAK requires a firmware file and an output directory."
    return 1
  fi
  if [[ -d "${lOUTPUT_DIR_OFRAK}" ]] && [[ -n "$(find "${lOUTPUT_DIR_OFRAK}" -mindepth 1 -print -quit)" ]]; then
    print_output "[-] OFRAK output directory is not empty - retaining existing artifacts."
    return 1
  fi

  mkdir -p -- "${lOUTPUT_DIR_OFRAK}" || return 1
  print_output "[*] Extracting ${ORANGE}${lFIRMWARE_PATH}${NC} with OFRAK to ${ORANGE}${lOUTPUT_DIR_OFRAK}${NC}"

  PATH="${lOFRAK_BIN%/*}:${PATH}" timeout --preserve-status --signal SIGINT 300m "${lOFRAK_BIN}" unpack \
    --recursive --exclude-components-missing-dependencies \
    --log-file "${lOFRAK_LOG}.debug" -o "${lOUTPUT_DIR_OFRAK}" -- "${lFIRMWARE_PATH}" \
    >"${lOFRAK_LOG}" 2>&1 </dev/null || lSTATUS="$?"

  print_output "[*] OFRAK extraction output" "" "${lOFRAK_LOG}"
  if [[ -f "${lOUTPUT_DIR_OFRAK}/__ofrak_info__" ]]; then
    mv -- "${lOUTPUT_DIR_OFRAK}/__ofrak_info__" "${lOFRAK_LOG}.info" || return 1
  fi
  if [[ "${lSTATUS}" -ne 0 ]]; then
    print_output "[-] OFRAK extraction failed (exit ${lSTATUS}) - check ${lOFRAK_LOG}, including license configuration."
  fi
  return "${lSTATUS}"
}
