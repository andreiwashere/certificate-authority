#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.

declare BASE_DIR
read -r -p 'Where do you want to save the Root CA? (eg /opt/ca): ' BASE_DIR
echo

declare CA_NAME
read -r -p "Root Certificate Authority Name: " CA_NAME
echo 

declare CA_LOCALITY
read -r -p "City where ${CA_NAME} is located (eg. Concord): " CA_LOCALITY
echo

declare CA_STATE
read -r -p "State Code (eg NH) where ${CA_NAME} is located: " CA_STATE
echo

declare ROOT_DOMAIN
read -r -p "Root Domain Name (eg. domain.com): " ROOT_DOMAIN
echo

if [ "${BASE_DIR}" == "" ]; then
  BASE_DIR="/opt/ca"
fi

if [ -n "$(ls -A "${BASE_DIR}")" ]; then
  echo "Already have data inside ${BASE_DIR}."
  exit 1
fi

mkdir -p "${BASE_DIR}/{root-ca,intermed-ca,tmp,certificates}"
echo "Created directories: "
echo "1. ${BASE_DIR}/root-ca"
echo "2. ${BASE_DIR}/intermed-ca"
echo "3. ${BASE_DIR}/tmp"
echo "4. ${BASE_DIR}/certificates"

declare ROOT_DIR
ROOT_DIR="${BASE_DIR}/root-ca"

declare ROOT_CNF_FILE
ROOT_CNF_FILE="${ROOT_DIR}/${ROOT_DOMAIN}.root-ca.cnf"

declare ROOT_KEY_FILE
ROOT_KEY_FILE="${ROOT_DIR}/private/${ROOT_DOMAIN}.root-ca.key.pem"

declare ROOT_CSR_FILE
ROOT_CSR_FILE="${ROOT_DIR}/${ROOT_DOMAIN}.root-ca.req.pem"

declare ROOT_CRT_FILE
ROOT_CRT_FILE="${ROOT_DIR}/${ROOT_DOMAIN}.root-ca.cert.pem"

declare ROOT_SERIAL_FILE
ROOT_SERIAL_FILE="${ROOT_DIR}/${ROOT_DOMAIN}.root-ca.serial"

declare ROOT_CRL_FILE
ROOT_CRL_FILE="${ROOT_DIR}/crl/${ROOT_DOMAIN}.root-ca.crl"

declare ROOT_INDEX_FILE
ROOT_INDEX_FILE="${ROOT_DIR}/${ROOT_DOMAIN}.root-ca.index"

declare ROOT_CRLNUM_FILE
ROOT_CRLNUM_FILE="${ROOT_DIR}/crl/${ROOT_DOMAIN}.root-ca.crlnum"

declare SYS_ROOT_CRT_FILE
SYS_ROOT_CRT_FILE="/etc/ssl/certs/ROOT-CA.${ROOT_DOMAIN}.crt"

declare SYS_INTERMED_CRT_FILE
SYS_INTERMED_CRT_FILE="/etc/ssl/certs/ROOT-CA.${ROOT_DOMAIN}.crt"

if [[ -f "${SYS_ROOT_CRT_FILE}" || -f "${SYS_INTERMED_CRT_FILE}" ]]; then
  echo "Already have certificates installed at ${SYS_ROOT_CRT_FILE} or ${SYS_INTERMED_CRT_FILE}."
  if [[ -f "${SYS_ROOT_CRT_FILE}" ]]; then
    head -n 2 "${SYS_ROOT_CRT_FILE}"
    echo "..."
    tail -n 2 "${SYS_ROOT_CRT_FILE}"
  fi
  if [[ -f "${SYS_INTERMED_CRT_FILE}" ]]; then
    head -n 2 "${SYS_INTERMED_CRT_FILE}"
    echo "..."
    tail -n 2 "${SYS_INTERMED_CRT_FILE}"
  fi
  echo "Exiting the script to protect these issued certificates."
  echo "Please delete these two files and re-try if you intend to reissue the Root Certificate Authority ${CA_NAME} for ${ROOT_DOMAIN}."
  exit 1
fi

cd "${ROOT_DIR}"
mkdir -p {certreqs,certs,crl,newcerts,private}
chmod 0700 private

declare -a domains=()
declare permitted_domain
declare choice
while true; do
  read -r -p "Add DNS Entry: " permitted_domain
  domains+=("${permitted_domain}")
  echo "Pending Entries: ${domains[*]}"
  read -r -p "Add another? [y|n]: " choice
  if [[ "$choice" =~ ^[Nn] ]]; then
    break
  fi 
done

echo "DNS entries for [name_constraints]: ${domains[*]}"
declare looks_good
read -r -p "Does this look good? [y|n]: " looks_good
if [[ "$looks_good" =~ ^[Nn] ]]; then
  echo "Existing the script since you indicated that you made a mistake... [did you say steak?]"
  exit 1
fi

echo "Creating the ${ROOT_CNF_FILE} file..."

echo 'CA_HOME                     = .' >> "${ROOT_CNF_FILE}"
echo 'RANDFILE                    = $ENV::CA_HOME/private/.rnd' >> "${ROOT_CNF_FILE}"
echo '' >> "${ROOT_CNF_FILE}"
echo '[ ca ]' >> "${ROOT_CNF_FILE}"
echo 'default_ca                  = root_ca' >> "${ROOT_CNF_FILE}"
echo '' >> "${ROOT_CNF_FILE}"
echo '[ root_ca ]' >> "${ROOT_CNF_FILE}"
echo 'dir                         = $ENV::CA_HOME' >> "${ROOT_CNF_FILE}"
echo 'certs                       = $dir/certs' >> "${ROOT_CNF_FILE}"
echo "serial                      = \$dir/${ROOT_DOMAIN}.root-ca.serial" >> "${ROOT_CNF_FILE}"
echo "database                    = \$dir/${ROOT_DOMAIN}.root-ca.index" >> "${ROOT_CNF_FILE}"
echo 'new_certs_dir               = $dir/newcerts' >> "${ROOT_CNF_FILE}"
echo "certificate                 = \$dir/${ROOT_DOMAIN}.root-ca.cert.pem" >> "${ROOT_CNF_FILE}"
echo "private_key                 = \$dir/private/${ROOT_DOMAIN}.root-ca.key.pem" >> "${ROOT_CNF_FILE}"
echo 'default_days                = 3333' >> "${ROOT_CNF_FILE}"
echo "crl                         = \$dir/crl/${ROOT_DOMAIN}.root-ca.crl" >> "${ROOT_CNF_FILE}"
echo 'crl_dir                     = $dir/crl' >> "${ROOT_CNF_FILE}"
echo "crlnumber                   = \$dir/crl/${ROOT_DOMAIN}.root-ca.crlnum" >> "${ROOT_CNF_FILE}"
echo 'name_opt                    = multiline, align' >> "${ROOT_CNF_FILE}"
echo 'cert_opt                    = no_pubkey' >> "${ROOT_CNF_FILE}"
echo 'copy_extensions             = copy' >> "${ROOT_CNF_FILE}"
echo 'crl_extensions              = crl_ext' >> "${ROOT_CNF_FILE}"
echo 'default_crl_days            = 180' >> "${ROOT_CNF_FILE}"
echo 'default_md                  = sha256' >> "${ROOT_CNF_FILE}"
echo 'preserve                    = no' >> "${ROOT_CNF_FILE}"
echo 'email_in_dn                 = no' >> "${ROOT_CNF_FILE}"
echo 'policy                      = policy' >> "${ROOT_CNF_FILE}"
echo 'unique_subject              = no' >> "${ROOT_CNF_FILE}"
echo '' >> "${ROOT_CNF_FILE}"
echo '[policy]' >> "${ROOT_CNF_FILE}"
echo 'countryName                 = optional' >> "${ROOT_CNF_FILE}"
echo 'stateOrProvinceName         = optional' >> "${ROOT_CNF_FILE}"
echo 'localityName                = optional' >> "${ROOT_CNF_FILE}"
echo 'organizationName            = supplied' >> "${ROOT_CNF_FILE}"
echo 'organizationalUnitName      = optional' >> "${ROOT_CNF_FILE}"
echo 'commonName                  = supplied' >> "${ROOT_CNF_FILE}"
echo '' >> "${ROOT_CNF_FILE}"
echo '[ req ]' >> "${ROOT_CNF_FILE}"
echo 'default_bits                = 4096' >> "${ROOT_CNF_FILE}"
echo "default_keyfile             = private/${ROOT_DOMAIN}.root-ca.key.pem" >> "${ROOT_CNF_FILE}"
echo 'encrypt_key                 = yes' >> "${ROOT_CNF_FILE}"
echo 'default_md                  = sha256' >> "${ROOT_CNF_FILE}"
echo 'string_mask                 = utf8only' >> "${ROOT_CNF_FILE}"
echo 'utf8                        = yes' >> "${ROOT_CNF_FILE}"
echo 'prompt                      = no' >> "${ROOT_CNF_FILE}"
echo 'req_extensions              = root-ca_req_ext' >> "${ROOT_CNF_FILE}"
echo 'distinguished_name          = distinguished_name' >> "${ROOT_CNF_FILE}"
echo 'subjectAltName              = @subject_alt_name' >> "${ROOT_CNF_FILE}"
echo '' >> "${ROOT_CNF_FILE}"
echo '[ root-ca_req_ext ]' >> "${ROOT_CNF_FILE}"
echo 'subjectKeyIdentifier        = hash' >> "${ROOT_CNF_FILE}"
echo 'subjectAltName              = @subject_alt_name' >> "${ROOT_CNF_FILE}"
echo '' >> "${ROOT_CNF_FILE}"
echo '[ distinguished_name ]' >> "${ROOT_CNF_FILE}"
echo 'countryName                 = US' >> "${ROOT_CNF_FILE}"
echo 'countryName_default         = US' >> "${ROOT_CNF_FILE}"
echo 'countryName_min             = 2' >> "${ROOT_CNF_FILE}"
echo 'countryName_max             = 2' >> "${ROOT_CNF_FILE}"
echo 'stateOrProvinceName         = State' >> "${ROOT_CNF_FILE}"
echo "stateOrProvinceName_default = ${CA_STATE}" >> "${ROOT_CNF_FILE}"
echo 'localityName                = Locality Name (eg City)' >> "${ROOT_CNF_FILE}"
echo "localityName_default        = ${CA_LOCALITY}" >> "${ROOT_CNF_FILE}"
echo '0.organizationName          = Organization Name (eg Company)' >> "${ROOT_CNF_FILE}"
echo "0.organizationName_default  = ${CA_NAME}" >> "${ROOT_CNF_FILE}"
echo 'commonName                  = Common Name (eg your servers hostname)' >> "${ROOT_CNF_FILE}"
echo 'commonName_max              = 64' >> "${ROOT_CNF_FILE}"
echo 'emailAddress                = Email Address' >> "${ROOT_CNF_FILE}"
echo 'emailAddress_max            = 64' >> "${ROOT_CNF_FILE}"
echo '' >> "${ROOT_CNF_FILE}"
echo '[ root-ca_ext ]' >> "${ROOT_CNF_FILE}"
echo 'basicConstraints            = critical, CA:true' >> "${ROOT_CNF_FILE}"
echo 'keyUsage                    = critical, keyCertSign, cRLSign' >> "${ROOT_CNF_FILE}"
echo 'nameConstraints             = critical, @name_constraints' >> "${ROOT_CNF_FILE}"
echo 'subjectKeyIdentifier        = hash' >> "${ROOT_CNF_FILE}"
echo 'subjectAltName              = @subject_alt_name' >> "${ROOT_CNF_FILE}"
echo 'authorityKeyIdentifier      = keyid:always' >> "${ROOT_CNF_FILE}"
echo 'issuerAltName               = issuer:copy' >> "${ROOT_CNF_FILE}"
echo 'authorityInfoAccess         = @auth_info_access' >> "${ROOT_CNF_FILE}"
echo 'crlDistributionPoints       = @crl_dist' >> "${ROOT_CNF_FILE}"
echo '' >> "${ROOT_CNF_FILE}"
echo '[ intermed-ca_ext ]' >> "${ROOT_CNF_FILE}"
echo 'basicConstraints            = critical, CA:true, pathlen:0' >> "${ROOT_CNF_FILE}"
echo 'keyUsage                    = critical, keyCertSign, cRLSign, digitalSignature' >> "${ROOT_CNF_FILE}"
echo 'subjectKeyIdentifier        = hash' >> "${ROOT_CNF_FILE}"
echo 'subjectAltName              = @subject_alt_name' >> "${ROOT_CNF_FILE}"
echo 'authorityKeyIdentifier      = keyid:always' >> "${ROOT_CNF_FILE}"
echo 'issuerAltName               = issuer:copy' >> "${ROOT_CNF_FILE}"
echo 'authorityInfoAccess         = @auth_info_access' >> "${ROOT_CNF_FILE}"
echo 'crlDistributionPoints       = @crl_dist' >> "${ROOT_CNF_FILE}"
echo '' >> "${ROOT_CNF_FILE}"
echo '[ crl_ext ]' >> "${ROOT_CNF_FILE}"
echo 'authorityKeyIdentifier      = keyid:always' >> "${ROOT_CNF_FILE}"
echo 'issuerAltName               = issuer:copy' >> "${ROOT_CNF_FILE}"
echo '' >> "${ROOT_CNF_FILE}"
echo '[ subject_alt_name ]' >> "${ROOT_CNF_FILE}"
echo "URI                         = http://ca.${ROOT_DOMAIN}/" >> "${ROOT_CNF_FILE}"
echo "email                       = certmaster@${ROOT_DOMAIN}" >> "${ROOT_CNF_FILE}"
echo '' >> "${ROOT_CNF_FILE}"
echo '[ name_constraints ]' >> "${ROOT_CNF_FILE}"

declare -i counter
counter=1
for item in "${domains[@]}"; do
  echo "permitted;DNS.${counter}    = ${item}" >> "${ROOT_CNF_FILE}"
  ((counter++))
done
echo "permitted;DNS.${counter}    = lan"
counter=1
for item in "${domains[@]}"; do
  echo "permitted;email.${counter} = ${item}" >> "${ROOT_CNF_FILE}"
  ((counter++))
done
echo "permitted;email.${counter}  = lan"
echo "" >> "${ROOT_CNF_FILE}"
echo '[ auth_info_access ]' >> "${ROOT_CNF_FILE}"
echo "caIssuers;URI               = http://ca.${ROOT_DOMAIN}/certs/Root_Certificate_Authority.pem" >> "${ROOT_CNF_FILE}"
echo "" >> "${ROOT_CNF_FILE}"
echo '[ crl_dist ]' >> "${ROOT_CNF_FILE}"
echo "URI.1                       = http://ca.${ROOT_DOMAIN}/crl/Root_Certificate_Authrity.crl" >> "${ROOT_CNF_FILE}"

echo "DONE creating ${ROOT_CNF_FILE}!"

declare INTERMED_DIR
INTERMED_DIR="${BASE_DIR}/intermed-ca"

declare INTERMED_CNF_FILE
INTERMED_CNF_FILE="${INTERMED_DIR}/${ROOT_DOMAIN}.intermed-ca.cnf"

declare INTERMED_KEY_FILE
INTERMED_KEY_FILE="${INTERMED_DIR}/private/${ROOT_DOMAIN}.intermed-ca.key.pem"

declare INTERMED_CSR_FILE
INTERMED_CSR_FILE="${INTERMED_DIR}/${ROOT_DOMAIN}.intermed-ca.req.pem"

declare INTERMED_CRT_FILE
INTERMED_CRT_FILE="${INTERMED_DIR}/${ROOT_DOMAIN}.intermed-ca.cert.pem"

declare INTERMED_SERIAL_FILE
INTERMED_SERIAL_FILE="${INTERMED_DIR}/${ROOT_DOMAIN}.intermed-ca.serial"

declare ROOT_CRL_FILE
INTERMED_CRL_FILE="${INTERMED_DIR}/crl/${ROOT_DOMAIN}.intermed-ca.crl"

declare ROOT_CRLNUM_FILE
INTERMED_CRL_FILE="${INTERMED_DIR}/crl/${ROOT_DOMAIN}.intermed-ca.crlnum"

cd "${INTERMED_DIR}"
mkdir -p {certreqs,certs,crl,newcerts,private}

chmod 0700 private

echo "Creating the ${INTERMED_CNF_FILE} file..."

echo 'CA_HOME                 = .' >> "${INTERMED_CNF_FILE}"
echo 'oid_section             = new_oids' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ new_oids ]' >> "${INTERMED_CNF_FILE}"
echo 'xmppAddr                = 1.3.6.1.5.5.7.8.5' >> "${INTERMED_CNF_FILE}"
echo 'dnsSRV                  = 1.3.6.1.5.5.7.8.7' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ ca ]' >> "${INTERMED_CNF_FILE}"
echo 'default_ca              = intermed_ca' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ intermed_ca ]' >> "${INTERMED_CNF_FILE}"
echo 'dir                     = $ENV::CA_HOME' >> "${INTERMED_CNF_FILE}"
echo 'certs                   = $dir/certs' >> "${INTERMED_CNF_FILE}"
echo "serial                  = \$dir/${ROOT_DOMAIN}.intermed-ca.serial" >> "${INTERMED_CNF_FILE}"
echo "database                = \$dir/${ROOT_DOMAIN}.intermed-ca.index" >> "${INTERMED_CNF_FILE}"
echo 'new_certs_dir           = $dir/newcerts' >> "${INTERMED_CNF_FILE}"
echo "certificate             = \$dir/${ROOT_DOMAIN}.intermed-ca.cert.pem" >> "${INTERMED_CNF_FILE}"
echo "private_key             = \$dir/private/${ROOT_DOMAIN}.intermed-ca.key.pem" >> "${INTERMED_CNF_FILE}"
echo 'default_days            = 3333' >> "${INTERMED_CNF_FILE}"
echo "crl                     = \$dir/crl/${ROOT_DOMAIN}.intermed-ca.crl" >> "${INTERMED_CNF_FILE}"
echo 'crl_dir                 = $dir/crl' >> "${INTERMED_CNF_FILE}"
echo "crlnumber               = \$dir/crl/${ROOT_DOMAIN}.intermed-ca.crlnum" >> "${INTERMED_CNF_FILE}"
echo 'name_opt                = multiline, align' >> "${INTERMED_CNF_FILE}"
echo 'cert_opt                = no_pubkey' >> "${INTERMED_CNF_FILE}"
echo 'copy_extensions         = copy' >> "${INTERMED_CNF_FILE}"
echo 'crl_extensions          = crl_ext' >> "${INTERMED_CNF_FILE}"
echo 'default_crl_days        = 36' >> "${INTERMED_CNF_FILE}"
echo 'default_md              = sha256' >> "${INTERMED_CNF_FILE}"
echo 'preserve                = no' >> "${INTERMED_CNF_FILE}"
echo 'email_in_dn             = no' >> "${INTERMED_CNF_FILE}"
echo 'policy                  = policy' >> "${INTERMED_CNF_FILE}"
echo 'unique_subject          = no' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[policy]' >> "${INTERMED_CNF_FILE}"
echo 'countryName             = optional' >> "${INTERMED_CNF_FILE}"
echo 'stateOrProvinceName     = optional' >> "${INTERMED_CNF_FILE}"
echo 'localityName            = optional' >> "${INTERMED_CNF_FILE}"
echo 'organizationName        = supplied' >> "${INTERMED_CNF_FILE}"
echo 'organizationalUnitName  = optional' >> "${INTERMED_CNF_FILE}"
echo 'commonName              = supplied' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ user_policy ]' >> "${INTERMED_CNF_FILE}"
echo 'countryName             = supplied' >> "${INTERMED_CNF_FILE}"
echo 'stateOrProvinceName     = optional ' >> "${INTERMED_CNF_FILE}"
echo 'localityName            = supplied' >> "${INTERMED_CNF_FILE}"
echo 'organizationName        = optional' >> "${INTERMED_CNF_FILE}"
echo 'organizationalUnitName  = optional' >> "${INTERMED_CNF_FILE}"
echo 'commonName              = supplied' >> "${INTERMED_CNF_FILE}"
echo 'emailAddress            = supplied' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ req ]' >> "${INTERMED_CNF_FILE}"
echo 'default_bits            = 4096' >> "${INTERMED_CNF_FILE}"
echo "default_keyfile         = private/${ROOT_DOMAIN}.intermed-ca.key.pem" >> "${INTERMED_CNF_FILE}"
echo 'encrypt_key             = yes' >> "${INTERMED_CNF_FILE}"
echo 'default_md              = sha256' >> "${INTERMED_CNF_FILE}"
echo 'string_mask             = utf8only' >> "${INTERMED_CNF_FILE}"
echo 'utf8                    = yes' >> "${INTERMED_CNF_FILE}"
echo 'prompt                  = no' >> "${INTERMED_CNF_FILE}"
echo 'req_extensions          = intermed-ca_req_ext' >> "${INTERMED_CNF_FILE}"
echo 'distinguished_name      = distinguished_name' >> "${INTERMED_CNF_FILE}"
echo 'subjectAltName          = @subject_alt_name' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ intermed-ca_req_ext ]' >> "${INTERMED_CNF_FILE}"
echo 'subjectKeyIdentifier    = hash' >> "${INTERMED_CNF_FILE}"
echo 'subjectAltName          = @subject_alt_name' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ distinguished_name ]' >> "${INTERMED_CNF_FILE}"
echo "organizationName        = ${CA_NAME}" >> "${INTERMED_CNF_FILE}"
echo "commonName              = ${CA_NAME} Intermediate Certificate Authority" >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ server_ext ]' >> "${INTERMED_CNF_FILE}"
echo 'basicConstraints        = CA:FALSE' >> "${INTERMED_CNF_FILE}"
echo 'keyUsage                = critical, digitalSignature, keyEncipherment' >> "${INTERMED_CNF_FILE}"
echo 'extendedKeyUsage        = critical, serverAuth, clientAuth' >> "${INTERMED_CNF_FILE}"
echo 'subjectKeyIdentifier    = hash' >> "${INTERMED_CNF_FILE}"
echo 'authorityKeyIdentifier  = keyid:always' >> "${INTERMED_CNF_FILE}"
echo 'issuerAltName           = issuer:copy' >> "${INTERMED_CNF_FILE}"
echo 'authorityInfoAccess     = @auth_info_access' >> "${INTERMED_CNF_FILE}"
echo 'crlDistributionPoints   = crl_dist' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ client_ext ]' >> "${INTERMED_CNF_FILE}"
echo 'basicConstraints        = CA:FALSE' >> "${INTERMED_CNF_FILE}"
echo 'keyUsage                = critical, digitalSignature' >> "${INTERMED_CNF_FILE}"
echo 'extendedKeyUsage        = critical, clientAuth' >> "${INTERMED_CNF_FILE}"
echo 'subjectKeyIdentifier    = hash' >> "${INTERMED_CNF_FILE}"
echo 'authorityKeyIdentifier  = keyid:always' >> "${INTERMED_CNF_FILE}"
echo 'issuerAltName           = issuer:copy' >> "${INTERMED_CNF_FILE}"
echo 'authorityInfoAccess     = @auth_info_access' >> "${INTERMED_CNF_FILE}"
echo 'crlDistributionPoints   = crl_dist' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ user_ext ]' >> "${INTERMED_CNF_FILE}"
echo 'basicConstraints        = CA:FALSE' >> "${INTERMED_CNF_FILE}"
echo 'keyUsage                = critical, digitalSignature, keyEncipherment' >> "${INTERMED_CNF_FILE}"
echo 'extendedKeyUsage        = critical, clientAuth, emailProtection' >> "${INTERMED_CNF_FILE}"
echo 'subjectKeyIdentifier    = hash' >> "${INTERMED_CNF_FILE}"
echo 'authorityKeyIdentifier  = keyid:always' >> "${INTERMED_CNF_FILE}"
echo 'issuerAltName           = issuer:copy' >> "${INTERMED_CNF_FILE}"
echo 'authorityInfoAccess     = @auth_info_access' >> "${INTERMED_CNF_FILE}"
echo 'crlDistributionPoints   = crl_dist' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ crl_ext ]' >> "${INTERMED_CNF_FILE}"
echo 'authorityKeyIdentifier  = keyid:always' >> "${INTERMED_CNF_FILE}"
echo 'issuerAltName           = issuer:copy' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ subject_alt_name ]' >> "${INTERMED_CNF_FILE}" 
echo "URI                     = http://ca.${ROOT_DOMAIN}/" >> "${INTERMED_CNF_FILE}"
echo "email                   = certmaster@${ROOT_DOMAIN}" >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ auth_info_access ]' >> "${INTERMED_CNF_FILE}"
echo "caIssuers;URI           = http://ca.${ROOT_DOMAIN}/certs/Intermediate_Certificate_Authority.crt" >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ crl_dist ]' >> "${INTERMED_CNF_FILE}"
echo "fullname                = URI:http://ca.${ROOT_DOMAIN}/crl/Intermediate_Certificate_Authority.crl" >> "${INTERMED_CNF_FILE}"

echo "DONE creating ${INTERMED_CNF_FILE}!"

cd "${ROOT_DIR}"

touch "${ROOT_INDEX_FILE}"
echo 00 > "${ROOT_CRLNUM_FILE}"
openssl rand -hex 16 > "${ROOT_SERIAL_FILE}"

export OPENSSL_CONF="${ROOT_CNF_FILE}"

declare ROOT_ALGORITHM
declare ROOT_ALGORITHM_LOWER
while true; do
  read -r -p "Which encryption algorithm will ${CA_NAME} for ${ROOT_DOMAIN} use? [rsa|ecc]: " ROOT_ALGORITHM
  echo
  ROOT_ALGORITHM_LOWER=$(echo "${ROOT_ALGORITHM}" | tr '[:upper:]' '[:lower:]')
  if [[ "${ROOT_ALGORITHM_LOWER}" =~ ^(ecc|rsa)$ ]]; then
    break
  else
    echo "Invalid encryption algorithm. Please choose from RSA or ECC."
  fi
done


declare ROOT_ALGO_CURVE
declare ROOT_ALGO_CURVE_LOWER
if grep -q "ecc" <<< "${ROOT_ALGORITHM_LOWER}"; then

  while true; do
    echo "Which curve shall be used for ${ROOT_DOMAIN} Root Certificate Authority? "
    echo
    echo "Choice  Curve           Field Size  Security   Performance"
    echo "------  -----           ----------  --------   -----------"
    echo "1       prime256v1      256 bits    Good       Good"
    echo "2       secp384r1       384 bits    Very good  Good"
    echo "3       brainpoolP512r1 512 bits    Excellent  Slow"
    echo "4       nistp521        521 bits    Excellent  Slow"
    echo "5       edwards25519    255 bits    Excellent  Fast"
    echo
    read -r -p "Which curve shall be used for ${ROOT_DOMAIN} Root Certificate Authority? [1-5] " ROOT_ALGO_CURVE
    echo
    ROOT_ALGO_CURVE_LOWER=$(echo "${ROOT_ALGO_CURVE}" | tr '[:upper:]' '[:lower:]')
    if [[ "${ROOT_ALGO_CURVE_LOWER}" =~ ^(prime256v1|secp384r1|brainpoolP512r1|nistp521|edwards25519|1|2|3|4|5)$ ]]; then
      case "${ROOT_ALGO_CURVE_LOWER}" in
        1) ROOT_ALGO_CURVE="prime256v1";;
        2) ROOT_ALGO_CURVE="secp384r1";;
        3) ROOT_ALGO_CURVE="brainpoolP512r1";;
        4) ROOT_ALGO_CURVE="nistp521";;
        5) ROOT_ALGO_CURVE="edwards25519";;
        *) ROOT_ALGO_CURVE="${ROOT_ALGO_CURVE_LOWER}";;
      esac
      break
    else
      echo "Invalid curve selected. Please try again."
    fi
  done

  openssl ecparam -out "${ROOT_KEY_FILE}" -name "${ROOT_ALGO_CURVE}" -genkey
  openssl req -new -sha512 -config "${ROOT_CNF_FILE}" -key "${ROOT_KEY_FILE}" -out "${ROOT_CSR_FILE}"
else
  openssl genrsa -out "${ROOT_KEY_FILE}" 4096
  openssl req -new -sha256 -config "${ROOT_CNF_FILE}" -key "${ROOT_KEY_FILE}" -out "${ROOT_CSR_FILE}"
fi

chmod 0400 "${ROOT_KEY_FILE}"

openssl rand -hex 16 > "${ROOT_SERIAL_FILE}"

openssl ca -selfsign \
           -in "${ROOT_CSR_FILE}" \
           -out "${ROOT_CRT_FILE}" \
           -extensions "root-ca_ext" \
           -startdate `date +%y%m%d000000Z -u -d -1day` \
           -enddate `date +%y%m%d000000Z -u -d +9years+99days`

openssl x509 -in "${ROOT_CRT_FILE}" \
             -noout \
             -text \
             -certopt no_version,no_pubkey,no_sigdump \
             -nameopt multiline

openssl verify -verbose \
               -CAfile "${ROOT_CRT_FILE}" "${ROOT_CRT_FILE}"

openssl ca -gencrl \
           -out "${ROOT_CRL_FILE}"

declare INSTALL_ROOT_CERT
if [[ $(sudo -v cp) || test -w "/etc/ssl/certs" ]]; then
  while true; do
    read -r -p "Install certificate $(basename "${ROOT_CRT_FILE}") inside /etc/ssl/certs? (requires sudo) [y|n]: " INSTALL_ROOT_CERT
    echo
    case "${INSTALL_ROOT_CERT}" in
      # Yy) { AA && AB } || B ;;
      Yy) { !$(sudo -v cp) && sudo cp "${ROOT_CRT_FILE}" "${SYS_ROOT_CRT_FILE}" } || cp "${ROOT_CRT_FILE}" "${SYS_ROOT_CRT_FILE}" ;;
      Nn) break;;
      *) echo "Invalid option ${INSTALL_ROOT_CERT}.";;
    esac
  done
fi

declare UPDATE_CA_CERTIFICATES
if [[ $(sudo -v update-ca-certificates) ]]; then
  while true; do
    read -r -p "Execute update-ca-certificates? (requires sudo) [y|n]: " UPDATE_CA_CERTIFICATES
    echo
    case "${UPDATE_CA_CERTIFICATES}" in 
      Yy) sudo update-ca-certificates;;
      Nn) break;;
      *) echo "Invalid option ${UPDATE_CA_CERTIFICATES}.";; 
    esac
  done
fi

unset OPENSSL_CONF

cd "${INTERMED_DIR}"

touch "${INTERMED_INDEX_FILE}"
echo 00 > "${INTERMED_CRLNUM_FILE}"
openssl rand -hex 16 > "${INTERMED_SERIAL_FILE}"

export OPENSSL_CONF="${INTERMED_CNF_FILE}"

if grep -q "ecc" <<< "${ROOT_ALGORITHM_LOWER}"; then
  openssl ecparam -out "${INTERMED_KEY_FILE}" -name "${ROOT_ALGO_CURVE}" -genkey
  openssl req -new -sha512 -config "${INTERMED_CNF_FILE}" -key "${INTERMED_KEY_FILE}" -out "${INTERMED_CSR_FILE}"
else
  openssl genrsa -out "${INTERMED_KEY_FILE}" 4096
  openssl req -new -sha256 -config "${INTERMED_CNF_FILE}" -key "${INTERMED_KEY_FILE}" -out "${INTERMED_CSR_FILE}"
fi

chmod 0400 "${INTERMED_KEY_FILE}"

openssl rand -hex 16 > "${INTERMED_SERIAL_FILE}"

openssl ca -selfsign \
           -in "${INTERMED_CSR_FILE}" \
           -out "${INTERMED_CRT_FILE}" \
           -extensions "intermed-ca_ext" \
           -startdate `date +%y%m%d000000Z -u -d -1day` \
           -enddate `date +%y%m%d000000Z -u -d +9years+99days`

openssl x509 -in "${INTERMED_CRT_FILE}" \
             -noout \
             -text \
             -certopt no_version,no_pubkey,no_sigdump \
             -nameopt multiline

openssl verify -verbose \
               -CAfile "${INTERMED_CRT_FILE}" "${INTERMED_CRT_FILE}"


openssl ca -gencrl \
           -out "${INTERMED_CRL_FILE}"

declare INSTALL_INTERMED_CERT
if [[ $(sudo -v cp) || test -w "/etc/ssl/certs" ]]; then
  while true; do
    read -r -p "Install certificate $(basename "${INTERMED_CRT_FILE}") inside /etc/ssl/certs? (requires sudo) [y|n]: " INSTALL_INTERMED_CERT
    echo
    case "${INSTALL_INTERMED_CERT}" in
      # Yy) { AA && AB } || B ;;
      Yy) { !$(sudo -v cp) && sudo cp "${INTERMED_CRT_FILE}" "${SYS_INTERMED_CRT_FILE}" } || cp "${INTERMED_CRT_FILE}" "${SYS_INTERMED_CRT_FILE}" ;;
      Nn) break;;
      *) echo "Invalid option ${INSTALL_INTERMED_CERT}.";;
    esac
  done
fi

if [[ $(sudo -v update-ca-certificates) ]]; then
  while true; do
    read -r -p "Execute update-ca-certificates? (requires sudo) [y|n]: " UPDATE_CA_CERTIFICATES
    echo
    case "${UPDATE_CA_CERTIFICATES}" in 
      Yy) sudo update-ca-certificates;;
      Nn) break;;
      *) echo "Invalid option ${UPDATE_CA_CERTIFICATES}.";; 
    esac
  done
fi
unset OPENSSL_CONF


