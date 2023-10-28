#!/bin/bash

declare COMMON_NAME
if [ -n "$1" ]; then
  COMMON_NAME="${1}"
else
  read -r -p 'Common Name (DNS or Email): ' COMMON_NAME
  echo 
fi

declare SAVE_TO
if [ -n "$2" ]; then
  SAVE_TO="${2}"
else
  SAVE_TO="$(pwd)/${COMMON_NAME}"
fi

declare STARTED_AT
STARTED_AT=$(pwd)

mkdir -p "${SAVE_TO}"
cd "${SAVE_TO}"

CNF_FILE="${COMMON_NAME}.cnf"

touch $CNF_FILE
{
  echo "[req]" 
  echo "days = 369" 
  echo "default_bits = 4096" 
  echo "default_md = sha256" 
  echo "default_keyfile = tls.key"
  echo "distinguished_name = req_distinquished_name"
  echo "x509_extensions = v3_ca"
  echo "req_extensions = v3_req"
  echo ""
  echo "[req_distinquished_name]"
  echo "C = Country"
  echo "ST = State"
  echo "L = City"
  echo "O = Company"
  echo "OU = Department"
  echo "emailAddress = Certificate Admin Email Address"
  echo "CN = Common Name"
  echo ""
  echo "[v3_ca]"
  echo "subjectAltName = @alt_names"
  echo "issuerAltName = issuer:copy"
  echo ""
  echo "[v3_req]"
  echo "extendedKeyUsage = serverAuth, clientAuth, codeSigning, emailProtection"
  echo "basicConstraints = CA:FALSE"
  echo "keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment"
  echo "subjectAltName = @alt_names"
  echo ""
  echo "[alt_names]"
  echo "DNS.1 = ${COMMON_NAME}"
} | tee -a $CNF_FILE > /dev/null

openssl genrsa -out "${COMMON_NAME}.key" 4096
openssl req -x509 -config $CNF_FILE -key "${COMMON_NAME}.key" -sha256 -nodes -out "${COMMON_NAME}.crt" -outform PEM -days 3600

ls -lah ${SAVE_TO}

cd "${STARTED_AT}"
