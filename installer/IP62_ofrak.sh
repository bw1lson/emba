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
# Description:  Installs OFRAK with a private, compatible Python runtime.
# Set OFRAK_ACCEPT_COMMUNITY_LICENSE=1 to explicitly accept its Community License.

IP62_ofrak() {
  module_title "${FUNCNAME[0]}"

  if [[ "${LIST_DEP}" -eq 1 || "${IN_DOCKER}" -eq 1 || "${DOCKER_SETUP}" -eq 0 || "${FULL}" -eq 1 ]]; then
    INSTALL_APP_LIST=()
    print_tool_info "python3-venv" 1
    print_tool_info "build-essential" 1
    print_tool_info "file" 1
    print_pip_info "uv"
    print_pip_info "ofrak"
    echo "[*] OFRAK 3.2.0 will use private CPython 3.10.20, provisioned with uv 0.11.14."
    echo "[*] Python downloads come from Astral's python-build-standalone releases with checksum verification."
    echo "[!] OFRAK Community licensing is restricted to eligible academic/non-commercial use."
    echo "[*] Review https://ofrak.com/license/ before setting OFRAK_ACCEPT_COMMUNITY_LICENSE=1."

    if [[ "${LIST_DEP}" -eq 1 || "${DOCKER_SETUP}" -eq 1 ]]; then
      return
    fi

    if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
      echo "[-] OFRAK installation requires x86_64 Linux for its pinned native dependencies."
      return 1
    fi

    local lOFRAK_VENV="${HOME_PATH%/}/external/ofrak_venv"
    local lOFRAK_BIN="${lOFRAK_VENV}/bin/ofrak"
    local lUV_VENV="${HOME_PATH%/}/external/ofrak_uv"
    local lUV_BIN="${lUV_VENV}/bin/uv"
    local lPYTHON_DIR="${HOME_PATH%/}/external/ofrak_python"
    local lPYTHON_PATH=""
    local lBACKUP_DIR=""
    local lBUILD_CONSTRAINT="${lUV_VENV}/ofrak-build-constraints.txt"
    local lUV_ARR=(env "UV_PYTHON_INSTALL_DIR=${lPYTHON_DIR}" "${lUV_BIN}" --no-config --no-cache)

    apt-get install "${INSTALL_APP_LIST[@]}" -y --no-install-recommends || return "$?"
    create_pipenv "${lUV_VENV}" || return "$?"
    "${lUV_VENV}/bin/python3" -m pip install --only-binary=:all: "uv==0.11.14" || return "$?"

    "${lUV_ARR[@]}" python install --no-bin "3.10.20" || return "$?"
    lPYTHON_PATH=$("${lUV_ARR[@]}" python find --managed-python --no-python-downloads --no-project --system "3.10.20") || return "$?"
    if [[ "${lPYTHON_PATH}" != "${lPYTHON_DIR}/"* || ! -x "${lPYTHON_PATH}" ]]; then
      echo "[-] No executable private OFRAK Python runtime found in ${lPYTHON_DIR}."
      return 1
    fi

    # Never mix packages built for a previous interpreter into the private environment.
    if [[ -e "${lOFRAK_VENV}" || -L "${lOFRAK_VENV}" ]]; then
      if [[ -L "${lOFRAK_VENV}" || ! -x "${lOFRAK_VENV}/bin/python3" || ! -f "${lOFRAK_VENV}/pyvenv.cfg" ]] ||
        ! grep -Fxq "version = 3.10.20" "${lOFRAK_VENV}/pyvenv.cfg" ||
        ! grep -Fxq "home = ${lPYTHON_PATH%/*}" "${lOFRAK_VENV}/pyvenv.cfg"; then
        lBACKUP_DIR=$(mktemp -d "${lOFRAK_VENV}.backup.XXXXXX") || return "$?"
        mv -- "${lOFRAK_VENV}" "${lBACKUP_DIR}/" || return "$?"
        echo "[*] Previous OFRAK environment retained in ${lBACKUP_DIR}; configure the new environment's license."
      fi
    fi

    if [[ ! -d "${lOFRAK_VENV}" ]]; then
      env -u PYTHONHOME -u PYTHONPATH "${lPYTHON_PATH}" -m venv "${lOFRAK_VENV}" || return "$?"
    fi
    printf 'setuptools==80.9.0\n' >"${lBUILD_CONSTRAINT}" || return "$?"
    "${lUV_ARR[@]}" pip install --python "${lOFRAK_VENV}/bin/python3" \
      --build-constraints "${lBUILD_CONSTRAINT}" "setuptools==80.9.0" "ofrak==3.2.0" || return "$?"
    "${lUV_ARR[@]}" pip check --python "${lOFRAK_VENV}/bin/python3" || return "$?"
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
