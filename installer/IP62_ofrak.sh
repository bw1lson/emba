#!/bin/bash

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
# Description:  Installs OFRAK in an isolated Python environment.
# Set OFRAK_ACCEPT_COMMUNITY_LICENSE=1 to explicitly accept its Community License.

IP62_ofrak() {
  module_title "${FUNCNAME[0]}"

  if [[ "${LIST_DEP}" -eq 1 || "${IN_DOCKER}" -eq 1 || "${DOCKER_SETUP}" -eq 0 || "${FULL}" -eq 1 ]]; then
    INSTALL_APP_LIST=()
    print_tool_info "python3-venv" 1
    print_tool_info "python3-dev" 1
    print_tool_info "build-essential" 1
    print_tool_info "file" 1
    print_pip_info "ofrak"
    echo "[*] OFRAK 3.2.0 will be installed in its own virtual environment."
    echo "[!] OFRAK Community licensing is restricted to eligible academic/non-commercial use."
    echo "[*] Review https://ofrak.com/license/ before setting OFRAK_ACCEPT_COMMUNITY_LICENSE=1."

    if [[ "${LIST_DEP}" -eq 1 || "${DOCKER_SETUP}" -eq 1 ]]; then
      return
    fi

    local lOFRAK_VENV="${HOME_PATH}/external/ofrak_venv"
    local lOFRAK_BIN="${lOFRAK_VENV}/bin/ofrak"

    apt-get install "${INSTALL_APP_LIST[@]}" -y --no-install-recommends || return "$?"
    create_pipenv "${lOFRAK_VENV}" || return "$?"
    "${lOFRAK_VENV}/bin/python3" -m pip install "ofrak==3.2.0" || return "$?"
    "${lOFRAK_BIN}" --help >/dev/null || return "$?"

    if [[ "${OFRAK_ACCEPT_COMMUNITY_LICENSE:-0}" == "1" ]]; then
      "${lOFRAK_BIN}" license --community --i-agree || return "$?"
      "${lOFRAK_BIN}" list >/dev/null || return "$?"
      echo "[+] OFRAK installed and Community License accepted."
    else
      echo "[!] OFRAK installed; configure an appropriate license before scanning:"
      echo "[*] ${lOFRAK_BIN} license"
      echo "[*] To automate Community acceptance, rerun with OFRAK_ACCEPT_COMMUNITY_LICENSE=1."
    fi
  fi
}
