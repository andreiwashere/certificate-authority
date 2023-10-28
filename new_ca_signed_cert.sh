#!/bin/bash


declare CA_DIR
: "${CA_DIR:=${1}}"

if [ ! -d "${CA_DIR}" ]; then
  mkdir -p "${CA_DIR}"
else
  while true; do
    read -r -t 30 -p "Enter the CA's root directory: " CA_DIR
    echo
    if [[ "${CA_DIR}" == "" || "${CA_DIR}" == "." || "${CA_DIR}" == ".." ]]; then
      echo "Invalid CA directory path provided."
      continue
    else
      if [ ! -d "${CA_DIR}" ]; then
        mkdir -p "${CA_DIR}"
      fi
      break
    fi
  done
fi

function safe_exit(){
  local msg="${1}"
  echo "${msg}"
  exit 1
}

cd "${CA_DIR}" || safe_exit "Failed to go to ${CA_DIR}."

[ ! -d "${CA_DIR}/intermed-ca" ] || safe_exit "Invalid CA root directory: ${CA_DIR} (missing intermed-ca subdirectory)."

declare FILE_INTERMED_PASSWD
FILE_INTERMED_PASSWD=$(find "${CA_DIR}/passwd" -maxdepth 1 -type f -name ".intermed-ca.*.passwd")

[[ -f "${FILE_INTERMED_PASSWD}" && -r "${FILE_INTERMED_PASSWD}" ]] || safe_exit "Permission denied to use the intermediate certificate authority."


