#!/bin/bash

set -e  # BEST PRACTICES: Exit immediately if a command exits with a non-zero status.
[ "${DEBUG:-0}" == "1" ] && set -x  # DEVELOPER EXPERIENCE: Enable debug mode, printing each command before it's executed.
set -u  # SECURITY: Exit if an unset variable is used to prevent potential security risks.
set -C  # SECURITY: Prevent existing files from being overwritten using the '>' operator.

# Where the CA will live
declare BASE_DIR
read -r -p 'Where do you want to save the Root CA? (default: /opt/ca): ' BASE_DIR
echo

if [ "${BASE_DIR}" == "" ]; then
  BASE_DIR="/opt/ca"
fi

mkdir -p "${BASE_DIR}"

if [ -n "$(ls -A "${BASE_DIR}")" ]; then
  echo "Already have data inside ${BASE_DIR}."
  exit 1
fi

# CA Corporate Name
declare CA_NAME
while true; do
  read -r -p "Root Certificate Authority Name: " CA_NAME
  echo 
  if [[ "${CA_NAME}"  != "" ]]; then
    break
  else
    echo "Invalid entry. Please enter the name of the Root Certificate Authority."
    echo
  fi
done

# CA's operating/legal city
declare CA_LOCALITY
while true; do
  read -r -p "City where ${CA_NAME} is located (eg. Concord): " CA_LOCALITY
  echo
  if [[ "${CA_LOCALITY}" != "" ]]; then
    break;
  else
    echo "Invalid entry. Please enter the full City name of ${CA_NAME}."
    echo 
  fi
done

# CA's operating/legal state code (2 chars max)
declare CA_STATE
while true; do
  read -r -p "State Code (eg NH) where ${CA_NAME} is located: " CA_STATE
  echo
  if [[ $CA_STATE =~ ^[A-Z]{2}$ ]]; then
    break
  else
    echo "Invalid state code. Please enter exactly two uppercase letters."
    echo 
  fi
done

# CA's primary domain name
declare ROOT_DOMAIN
while true; do
  read -r -p "Root Domain Name (eg. domain.com): " ROOT_DOMAIN
  echo
  if [[ $ROOT_DOMAIN =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    break
  else
    echo "Invalid domain format. Please enter a valid domain."
    echo
  fi
done

echo "Created directories: "
mkdir -p "${BASE_DIR}/root-ca"
echo "1. ${BASE_DIR}/root-ca"

mkdir -p "${BASE_DIR}/intermed-ca"
echo "2. ${BASE_DIR}/intermed-ca"

mkdir -p "${BASE_DIR}/tmp"
echo "3. ${BASE_DIR}/tmp"

mkdir -p "${BASE_DIR}/certificates"
echo "4. ${BASE_DIR}/certificates"

mkdir -p "${BASE_DIR}/passwd"
echo "5. ${BASE_DIR}/passwd"

echo "Defining the script's environment..."
declare FILE_ROOT_PASSWD
declare FILE_INTERMED_PASSWD
FILE_ROOT_PASSWD="${BASE_DIR}/passwd/.root-ca.${ROOT_DOMAIN}.passwd"
FILE_INTERMED_PASSWD="${BASE_DIR}/passwd/.intermed-ca.${ROOT_DOMAIN}.passwd"

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
SYS_INTERMED_CRT_FILE="/etc/ssl/certs/INTERMED-CA.${ROOT_DOMAIN}.crt"

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

echo "Completed defining the Root Certificate's dependencies."

cd "${ROOT_DIR}"
echo "Creating the ${ROOT_DIR}/{certreqs,certs,crl,newcerts,private} directories..."
mkdir -p {certreqs,certs,crl,newcerts,private}
echo "Securing the private key directory..."
chmod 0700 private
echo

declare -a domains=()
echo "List of Permitted Domains for Root CA: ${domains[*]}"
echo
echo "You need to manually add ${ROOT_DOMAIN}."
echo 
declare permitted_domain
declare choice
while true; do
  read -r -p "Add DNS Entry: " permitted_domain
  if [[ "${permitted_domain}" == "" ]]; then 
    echo "Invalid entry! Rejected '${permitted_domain}'."
    continue
  fi
  domains+=("${permitted_domain}")
  echo "Pending Entries: ${domains[*]}"
  read -r -p "Add another? [y*|n]: " choice
  if [[ "$choice" =~ ^[Nn] ]]; then
    break
  fi 
done

echo "DNS entries for [name_constraints]: ${domains[*]}"
echo
declare looks_good
read -r -p "Does this look good? [y|n]: " looks_good
if [[ "$looks_good" =~ ^[Nn] ]]; then
  echo "Existing the script since you indicated that you made a mistake... [did you say steak?]"
  exit 1
fi

echo "The Root CA's data directory: ${ROOT_DIR}"
tree -L 5 "${ROOT_DIR}"

echo
echo "Summary of variables:"
echo "1. CA_NAME = ${CA_NAME}"
echo "2. CA_LOCALITY = ${CA_LOCALITY}"
echo "3. CA_STATE = ${CA_STATE}"
echo "4. ROOT_CNF_FILE = ${ROOT_CNF_FILE}"
echo "5. ROOT_DOMAIN = ${ROOT_DOMAIN}"
echo "6. ROOT_CNF_FILE = ${ROOT_CNF_FILE}"
echo "7. ROOT_DOMAIN = ${ROOT_DOMAIN}"
echo "8. domains = ${domains[*]}"

echo "Creating the ${ROOT_CNF_FILE} file..."

unset CA_HOME

echo "Created the private openssl .rnd file."
touch "${ROOT_DIR}/private/.rnd"

export CA_HOME="${ROOT_DIR}"

echo

echo "RANDFILE                          = ${ROOT_DIR}/private/.rnd"                         >> "${ROOT_CNF_FILE}"
echo '[ ca ]'                                                                               >> "${ROOT_CNF_FILE}"
echo 'default_ca                        = root_ca'                                          >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[ root_ca ]'                                                                          >> "${ROOT_CNF_FILE}"
echo "dir                               = ${ROOT_DIR}"                                      >> "${ROOT_CNF_FILE}"
echo 'certs                             = $dir/certs'                                       >> "${ROOT_CNF_FILE}"
echo 'crl_dir                           = $dir/crl'                                         >> "${ROOT_CNF_FILE}"
echo 'new_certs_dir                     = $dir/newcerts'                                    >> "${ROOT_CNF_FILE}"
echo "database                          = \$dir/${ROOT_DOMAIN}.root-ca.index"               >> "${ROOT_CNF_FILE}"
echo "serial                            = \$dir/${ROOT_DOMAIN}.root-ca.serial"              >> "${ROOT_CNF_FILE}"
echo "rand_serial                       = yes"                                              >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo "certificate                       = \$dir/${ROOT_DOMAIN}.root-ca.cert.pem"            >> "${ROOT_CNF_FILE}"
echo "private_key                       = \$dir/private/${ROOT_DOMAIN}.root-ca.key.pem"     >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo "crlnumber                         = \$dir/crl/${ROOT_DOMAIN}.root-ca.crlnum"          >> "${ROOT_CNF_FILE}"
echo "crl                               = \$dir/crl/${ROOT_DOMAIN}.root-ca.crl"             >> "${ROOT_CNF_FILE}"
echo 'crl_extensions                    = crl_ext'                                          >> "${ROOT_CNF_FILE}"
echo 'default_crl_days                  = 180'                                              >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo 'default_md                        = sha256'                                           >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo 'name_opt                          = multiline, align'                                 >> "${ROOT_CNF_FILE}"
echo 'cert_opt                          = no_pubkey'                                        >> "${ROOT_CNF_FILE}"
echo 'default_days                      = 3333'                                             >> "${ROOT_CNF_FILE}"
echo 'preserve                          = no'                                               >> "${ROOT_CNF_FILE}"
echo 'policy                            = policy_strict'                                    >> "${ROOT_CNF_FILE}"
echo 'copy_extensions                   = copy'                                             >> "${ROOT_CNF_FILE}"
echo 'email_in_dn                       = no'                                               >> "${ROOT_CNF_FILE}"
echo 'unique_subject                    = no'                                               >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[policy_strict]'                                                                      >> "${ROOT_CNF_FILE}"
echo 'countryName                       = optional'                                         >> "${ROOT_CNF_FILE}"
echo 'stateOrProvinceName               = optional'                                         >> "${ROOT_CNF_FILE}"
echo 'localityName                      = optional'                                         >> "${ROOT_CNF_FILE}"
echo 'organizationName                  = optional'                                         >> "${ROOT_CNF_FILE}"
echo 'emailAddress                      = optional'                                         >> "${ROOT_CNF_FILE}"
echo 'organizationalUnitName            = optional'                                         >> "${ROOT_CNF_FILE}"
echo 'commonName                        = supplied'                                         >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[ req ]'                                                                              >> "${ROOT_CNF_FILE}"
echo 'default_bits                      = 4096'                                             >> "${ROOT_CNF_FILE}"
echo "default_keyfile                   = private/${ROOT_DOMAIN}.root-ca.key.pem"           >> "${ROOT_CNF_FILE}"
echo 'encrypt_key                       = yes'                                              >> "${ROOT_CNF_FILE}"
echo 'default_md                        = sha256'                                           >> "${ROOT_CNF_FILE}"
echo 'string_mask                       = utf8only'                                         >> "${ROOT_CNF_FILE}"
echo 'utf8                              = yes'                                              >> "${ROOT_CNF_FILE}"
echo 'prompt                            = no'                                               >> "${ROOT_CNF_FILE}"
echo 'req_extensions                    = root-ca_req_ext'                                  >> "${ROOT_CNF_FILE}"
echo 'distinguished_name                = distinguished_name'                               >> "${ROOT_CNF_FILE}"
echo 'subjectAltName                    = @subject_alt_name'                                >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[ root-ca_req_ext ]'                                                                  >> "${ROOT_CNF_FILE}"
echo 'subjectKeyIdentifier              = hash'                                             >> "${ROOT_CNF_FILE}"
echo 'subjectAltName                    = @subject_alt_name'                                >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[ distinguished_name ]'                                                               >> "${ROOT_CNF_FILE}"
#echo 'countryName                       = US'                                               >> "${ROOT_CNF_FILE}"
#echo 'stateOrProvinceName               = State'                                            >> "${ROOT_CNF_FILE}"
#echo 'localityName                      = Locality Name'                                    >> "${ROOT_CNF_FILE}"
#echo '0.organizationName                = Organization Name'                                >> "${ROOT_CNF_FILE}"
echo "organizationName                  = ${CA_NAME}"                                       >> "${ROOT_CNF_FILE}"
#echo 'organizationalUnitName            = Organizational Unit Name'                         >> "${ROOT_CNF_FILE}"
echo "commonName                        = ${ROOT_DOMAIN}"                                   >> "${ROOT_CNF_FILE}"
echo "emailAddress                      = certmaster@${ROOT_DOMAIN}"                        >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
#echo 'countryName_default               = US'                                               >> "${ROOT_CNF_FILE}"
#echo "stateOrProvinceName_default       = ${CA_STATE}"                                      >> "${ROOT_CNF_FILE}"
#echo "localityName_default              = ${CA_LOCALITY}"                                   >> "${ROOT_CNF_FILE}"
#echo "0.organizationName_default        = ${CA_NAME}"                                       >> "${ROOT_CNF_FILE}"
#echo "0.organizationalUnitName_default  = ${CA_NAME}"                                       >> "${ROOT_CNF_FILE}"
#echo 'countryName_min                   = 2'                                                >> "${ROOT_CNF_FILE}"
#echo 'countryName_max                   = 2'                                                >> "${ROOT_CNF_FILE}"
#echo 'commonName_max                    = 64'                                               >> "${ROOT_CNF_FILE}"
#echo 'emailAddress_max                  = 64'                                               >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[ root-ca_ext ]'                                                                      >> "${ROOT_CNF_FILE}"
echo 'basicConstraints                  = critical, CA:true'                                >> "${ROOT_CNF_FILE}"
echo 'keyUsage                          = critical, keyCertSign, cRLSign, digitalSignature' >> "${ROOT_CNF_FILE}"
echo 'nameConstraints                   = critical, @name_constraints'                      >> "${ROOT_CNF_FILE}"
echo 'subjectKeyIdentifier              = hash'                                             >> "${ROOT_CNF_FILE}"
echo 'subjectAltName                    = @subject_alt_name'                                >> "${ROOT_CNF_FILE}"
echo 'authorityKeyIdentifier            = keyid:always'                                     >> "${ROOT_CNF_FILE}"
echo 'issuerAltName                     = issuer:copy'                                      >> "${ROOT_CNF_FILE}"
echo 'authorityInfoAccess               = @auth_info_access'                                >> "${ROOT_CNF_FILE}"
echo 'crlDistributionPoints             = @crl_dist'                                        >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[ intermed-ca_ext ]'                                                                  >> "${ROOT_CNF_FILE}"
echo 'basicConstraints                  = critical, CA:true, pathlen:0'                     >> "${ROOT_CNF_FILE}"
echo 'keyUsage                          = critical, keyCertSign, cRLSign, digitalSignature' >> "${ROOT_CNF_FILE}"
echo 'subjectKeyIdentifier              = hash'                                             >> "${ROOT_CNF_FILE}"
echo 'subjectAltName                    = @subject_alt_name'                                >> "${ROOT_CNF_FILE}"
echo 'authorityKeyIdentifier            = keyid:always'                                     >> "${ROOT_CNF_FILE}"
echo 'issuerAltName                     = issuer:copy'                                      >> "${ROOT_CNF_FILE}"
echo 'authorityInfoAccess               = @auth_info_access'                                >> "${ROOT_CNF_FILE}"
echo 'crlDistributionPoints             = @crl_dist'                                        >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[ crl_ext ]'                                                                          >> "${ROOT_CNF_FILE}"
echo 'authorityKeyIdentifier            = keyid:always'                                     >> "${ROOT_CNF_FILE}"
echo 'issuerAltName                     = issuer:copy'                                      >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[ subject_alt_name ]'                                                                 >> "${ROOT_CNF_FILE}"
echo "URI                               = http://ca.${ROOT_DOMAIN}/"                        >> "${ROOT_CNF_FILE}"
echo "email                             = certmaster@${ROOT_DOMAIN}"                        >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[ auth_info_access ]'                                                                 >> "${ROOT_CNF_FILE}"
echo "caIssuers;URI                     = http://ca.${ROOT_DOMAIN}/certs/Root_CA.crt"       >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[ crl_dist ]'                                                                         >> "${ROOT_CNF_FILE}"
echo "URI.1                             = http://ca.${ROOT_DOMAIN}/crl/Root_CA.crl"         >> "${ROOT_CNF_FILE}"
echo ''                                                                                     >> "${ROOT_CNF_FILE}"
echo '[ name_constraints ]'                                                                 >> "${ROOT_CNF_FILE}"
declare -i counter
counter=1
for item in "${domains[@]}"; do
  echo "permitted;DNS.${counter}    = ${item}"                                              >> "${ROOT_CNF_FILE}"
  ((counter++))
done
echo "permitted;DNS.${counter}    = lan"                                                    >> "${ROOT_CNF_FILE}"
counter=1
for item in "${domains[@]}"; do
  echo "permitted;email.${counter} = ${item}"                                               >> "${ROOT_CNF_FILE}"
  ((counter++))
done
echo "permitted;email.${counter}  = lan"                                                    >> "${ROOT_CNF_FILE}"


echo "DONE creating ${ROOT_CNF_FILE}!"

echo "Defining the Intermediate Certificate's dependencies..."

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

declare INTERMED_CRL_FILE
INTERMED_CRL_FILE="${INTERMED_DIR}/crl/${ROOT_DOMAIN}.intermed-ca.crl"

declare INTERMED_CRLNUM_FILE
INTERMED_CRLNUM_FILE="${INTERMED_DIR}/crl/${ROOT_DOMAIN}.intermed-ca.crlnum"

declare INTERMED_INDEX_FILE
INTERMED_INDEX_FILE="${INTERMED_DIR}/${ROOT_DOMAIN}.intermed-ca.index"

echo "Creating the directories inside ${INTERMED_DIR}"

cd "${INTERMED_DIR}"
mkdir -p "${INTERMED_DIR}/certreqs"
mkdir -p "${INTERMED_DIR}/certs"
mkdir -p "${INTERMED_DIR}/crl"
mkdir -p "${INTERMED_DIR}/newcerts"
mkdir -p "${INTERMED_DIR}/private"

echo "Securing the intermediate certificate's private key directory"
chmod 0700 private

echo "Intermediate CA's directory: ${INTERMED_DIR}"
tree -L 5 "${INTERMED_DIR}"

echo "Created the intermediate private key's openssl .rnd file."
touch "${INTERMED_DIR}/private/.rnd"

echo "Creating the ${INTERMED_CNF_FILE} file..."

unset CA_HOME

export CA_HOME="${INTERMED_DIR}"

#echo "CA_HOME                 = ${INTERMED_DIR}" >> "${INTERMED_CNF_FILE}"
#echo 'oid_section             = new_oids' >> "${INTERMED_CNF_FILE}"
#echo '' >> "${INTERMED_CNF_FILE}"
#echo '[ new_oids ]' >> "${INTERMED_CNF_FILE}"
#echo 'xmppAddr                = 1.3.6.1.5.5.7.8.5' >> "${INTERMED_CNF_FILE}"
#echo 'dnsSRV                  = 1.3.6.1.5.5.7.8.7' >> "${INTERMED_CNF_FILE}"
#echo '' >> "${INTERMED_CNF_FILE}"
echo '[ ca ]' >> "${INTERMED_CNF_FILE}"
echo 'default_ca              = intermed_ca' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ intermed_ca ]' >> "${INTERMED_CNF_FILE}"
echo "dir                     = ${INTERMED_DIR}" >> "${INTERMED_CNF_FILE}"
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
echo 'req_extensions          = req_ext' >> "${INTERMED_CNF_FILE}"
echo 'distinguished_name      = distinguished_name' >> "${INTERMED_CNF_FILE}"
echo 'subjectAltName          = @subject_alt_name' >> "${INTERMED_CNF_FILE}"
echo '' >> "${INTERMED_CNF_FILE}"
echo '[ req_ext ]' >> "${INTERMED_CNF_FILE}"
echo 'subjectKeyIdentifier    = hash' >> "${INTERMED_CNF_FILE}"
echo 'subjectAltName          = @subject_alt_name' >> "${INTERMED_CNF_FILE}"
#echo 'xmppAddr                = @{xmppAddr}' >> "${INTERMED_CNF_FILE}"
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

echo "Creating the Root CA's index file."
touch "${ROOT_INDEX_FILE}"

echo "Creating the Root CA's CRLNum file."
echo 00 > "${ROOT_CRLNUM_FILE}"

export OPENSSL_CONF="${ROOT_CNF_FILE}"

echo

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

function generate_random_password() {
  # Usage: generate_random_password <password_length>

  local password_length="${1:-16}"

  # Generate random bytes and encode them in base64. Then remove any non-alphanumeric characters.
  local password=$(openssl rand -base64 $((password_length * 3 / 4 + 1)) | tr -dc 'a-zA-Z0-9' | head -c $password_length)

  echo "${password}"
}


declare ROOT_ALGO_CURVE
declare ROOT_ALGO_CURVE_LOWER

declare ROOT_BIT_LENGTH
declare ROOT_BIT_LENGTH_LOWER


declare SUGGEST_ROOT_PASSWD
SUGGEST_ROOT_PASSWD="$(generate_random_password 72)"
echo "${SUGGEST_ROOT_PASSWD}" | tee -a "${FILE_ROOT_PASSWD}" > /dev/null
chmod 0400 "${FILE_ROOT_PASSWD}"
echo "Generated a secure password for the Root Certificate Authority and saved it inside ${FILE_ROOT_PASSWD} with 0400 permissions."
echo

declare SUGGEST_INTERMED_PASSWD
SUGGEST_INTERMED_PASSWD="$(generate_random_password 72)"
echo "${SUGGEST_INTERMED_PASSWD}" | tee -a "${FILE_INTERMED_PASSWD}" > /dev/null
chmod 0400 "${FILE_INTERMED_PASSWD}"
echo "Generated a secure password for the Intermediate Certificate Authority and saved it inside ${FILE_INTERMED_PASSWD} with 0400 permissions."
echo

if grep -q "ecc" <<< "${ROOT_ALGORITHM_LOWER}"; then

  while true; do
    echo "Which Elliptic Curve (EC) shall be used for ${ROOT_DOMAIN} Root Certificate Authority? "
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

  echo "${ROOT_ALGO_CURVE}" | tee -a "${BASE_DIR}/passwd/.root-ca.ecc-curve" > /dev/null
  echo "Saved the Elliptic Curve choice to ${BASE_DIR}/passwd/.root-ca.ecc-curve"

  case "${ROOT_ALGO_CURVE}" in
    prime256v1) 
      openssl genpkey -algorithm EC -out "${ROOT_KEY_FILE}" -pkeyopt ec_paramgen_curve:prime256v1 -aes-256-cbc -pass "file:${FILE_ROOT_PASSWD}"
      ;;
    secp384r1) 
      openssl genpkey -algorithm EC -out "${ROOT_KEY_FILE}" -pkeyopt ec_paramgen_curve:secp384r1 -aes-256-cbc -pass "file:${FILE_ROOT_PASSWD}"
      ;;
    brainpoolP512r1) 
      openssl genpkey -algorithm EC -out "${ROOT_KEY_FILE}" -pkeyopt ec_paramgen_curve:brainpoolP512r1 -aes-256-cbc -pass "file:${FILE_ROOT_PASSWD}"
      ;;
    nistp521) 
      openssl genpkey -algorithm EC -out "${ROOT_KEY_FILE}" -pkeyopt ec_paramgen_curve:secp521r1 -aes-256-cbc -pass "file:${FILE_ROOT_PASSWD}"
      ;;
    *) # ed25519 or edwards25519 
      openssl genpkey -algorithm ED25519 -out "${ROOT_KEY_FILE}" -aes-256-cbc -pass "file:${FILE_ROOT_PASSWD}"
      ;;
  esac
  echo "Generated the Root CA's private key file: ${ROOT_KEY_FILE}"

  openssl req -new -sha512 -config "${ROOT_CNF_FILE}" -key "${ROOT_KEY_FILE}" -out "${ROOT_CSR_FILE}" -passin "file:${FILE_ROOT_PASSWD}"
  echo "Generated the Root CA's CSR file: ${ROOT_CSR_FILE}"
else
  while true; do
    echo "Which RSA bit length shall be used for ${ROOT_DOMAIN} Root Certificate Authority? "
    echo ""
    echo "Choice  Bits  Performance  Security"
    echo "------  ----  -----------  --------"
    echo "1       2048  Excellent    Fast"
    echo "2       3072  Excellent    Good"
    echo "3       4096  Very good    Good"
    echo "4       8192  Good         Slow"
    echo ""
    read -r -p "Which bit length shall be used? [1-4]: " ROOT_BIT_LENGTH
    echo
    ROOT_BIT_LENGTH_LOWER=$(echo "${ROOT_BIT_LENGTH}" | tr '[:upper:]' '[:lower:]')
    if [[ "${ROOT_ALGO_CURVE_LOWER}" =~ ^(2048|3072|4096|8192|1|2|3|4)$ ]]; then
      case "${ROOT_ALGO_CURVE_LOWER}" in
        1) ROOT_BIT_LENGTH="2048";;
        2) ROOT_BIT_LENGTH="3072";;
        3) ROOT_BIT_LENGTH="4096";;
        4) ROOT_BIT_LENGTH="8192";;
        *) ROOT_BIT_LENGTH="${ROOT_BIT_LENGTH_LOWER}";;
      esac
      break
    else
      echo "Invalid bit length selected. Please try again."
    fi
  done

  openssl genrsa -aes256 -out "${ROOT_KEY_FILE}" -passout "file:${FILE_ROOT_PASSWD}" "${ROOT_BIT_LENGTH}"
  echo "Generated the Root CA's private key file: ${ROOT_KEY_FILE}"

  openssl req -new -sha256 -config "${ROOT_CNF_FILE}" -key "${ROOT_KEY_FILE}" -passin "file:${FILE_ROOT_PASSWD}" -out "${ROOT_CSR_FILE}"
  echo "Generated the Root CA's CSR file: ${ROOT_CSR_FILE}"
fi

chmod 0400 "${ROOT_KEY_FILE}"
echo "Secured the Root CA's private key."

openssl rand -hex 16 > "${ROOT_SERIAL_FILE}"
echo "Generated a random serial for the Root CA at ${ROOT_SERIAL_FILE}"

echo "Signing the Root CA..."
openssl ca -selfsign \
           -in "${ROOT_CSR_FILE}" \
           -out "${ROOT_CRT_FILE}" \
           -extensions "root-ca_ext" \
           -startdate `date +%y%m%d000000Z -u -d -1day` \
           -enddate `date +%y%m%d000000Z -u -d +17years+17days` \
           -passin "file:${FILE_ROOT_PASSWD}"

echo "Here's the new Root CA header..."
openssl x509 -in "${ROOT_CRT_FILE}" \
             -noout \
             -text \
             -certopt no_version,no_pubkey,no_sigdump \
             -nameopt multiline

echo "Generating the Certificate Revoke List (CRL) for the Root CA at ${ROOT_CRL_FILE}"
openssl ca -gencrl \
           -out "${ROOT_CRL_FILE}" \
           -passin "file:${FILE_ROOT_PASSWD}"

cp "${ROOT_CRT_FILE}" "${BASE_DIR}/certificates/Root_Certificate_Authority.${ROOT_DOMAIN}.crt"
echo "Copied the $(basename "${ROOT_CRT_FILE}") into ${BASE_DIR}/certificates"

unset OPENSSL_CONF

echo "Moving into the Intermediate Certificate's workspace at ${INTERMED_DIR}"
cd "${INTERMED_DIR}"

touch "${INTERMED_INDEX_FILE}"
echo "Created the intermediate index file at ${INTERMED_INDEX_FILE}"

echo 00 > "${INTERMED_CRLNUM_FILE}"
echo "Assigned 00 to the intermediate CRLNum file ${INTERMED_CRLNUM_FILE}"

openssl rand -hex 16 > "${INTERMED_SERIAL_FILE}"
echo "Created the intermediate serial file ${INTERMED_SERIAL_FILE}"

export OPENSSL_CONF="${INTERMED_CNF_FILE}"

if grep -q "ecc" <<< "${ROOT_ALGORITHM_LOWER}"; then
  case "${ROOT_ALGO_CURVE}" in
    prime256v1) 
      openssl genpkey -algorithm EC -out "${INTERMED_KEY_FILE}" -pkeyopt ec_paramgen_curve:prime256v1 -aes-256-cbc -pass "file:${FILE_INTERMED_PASSWD}"
      ;;
    secp384r1) 
      openssl genpkey -algorithm EC -out "${INTERMED_KEY_FILE}" -pkeyopt ec_paramgen_curve:secp384r1 -aes-256-cbc -pass "file:${FILE_INTERMED_PASSWD}"
      ;;
    brainpoolP512r1) 
      openssl genpkey -algorithm EC -out "${INTERMED_KEY_FILE}" -pkeyopt ec_paramgen_curve:brainpoolP512r1 -aes-256-cbc -pass "file:${FILE_INTERMED_PASSWD}"
      ;;
    nistp521) 
      openssl genpkey -algorithm EC -out "${INTERMED_KEY_FILE}" -pkeyopt ec_paramgen_curve:secp521r1 -aes-256-cbc -pass "file:${FILE_INTERMED_PASSWD}"
      ;;
    *) # ed25519 or edwards25519 
      openssl genpkey -algorithm ED25519 -out "${INTERMED_KEY_FILE}" -aes-256-cbc -pass "file:${FILE_INTERMED_PASSWD}"
      ;;
  esac
  echo "Generated the Intermediate Certificate's private key file ${INTERMED_KEY_FILE}"

  openssl req -new -sha512 -config "${INTERMED_CNF_FILE}" -key "${INTERMED_KEY_FILE}" -out "${INTERMED_CSR_FILE}"  -passin "file:${FILE_INTERMED_PASSWD}"
  echo "Generated the Intermediate Certificate's signing request file ${INTERMED_CSR_FILE}"
else
  openssl genrsa -aes256 -out "${INTERMED_KEY_FILE}" -passout "file:${FILE_INTERMED_PASSWD}" "${ROOT_BIT_LENGTH}"
  echo "Generated the Intermediate Certificate's private key file ${INTERMED_KEY_FILE}"

  openssl req -new -sha256 -config "${INTERMED_CNF_FILE}" -key "${INTERMED_KEY_FILE}" -passin "file:${FILE_INTERMED_PASSWD}" -out "${INTERMED_CSR_FILE}"
  echo "Generated the Intermediate Certificate's signing request file ${INTERMED_CSR_FILE}"
fi

chmod 0400 "${INTERMED_KEY_FILE}"
echo "Secured the intermediate certificate's private key file ${INTERMED_KEY_FILE}"

cp "${INTERMED_CSR_FILE}" "${ROOT_DIR}/certreqs/$(basename "${INTERMED_CSR_FILE}")"
echo "Copied $(basename "${INTERMED_CSR_FILE}") into ${ROOT_DIR}/certreqs"

unset OPENSSL_CONF


cd "${ROOT_DIR}"

export OPENSSL_CONF="${ROOT_CNF_FILE}"

echo "Signing the intermediate certificate with the Root CA..."
openssl ca -in "${ROOT_DIR}/certreqs/$(basename "${INTERMED_CSR_FILE}")" \
           -out "${ROOT_DIR}/certs/intermed-ca.${ROOT_DOMAIN}.pem" \
           -extensions "intermed-ca_ext" \
           -startdate `date +%y%m%d000000Z -u -d -1day` \
           -enddate `date +%y%m%d000000Z -u -d +17years+17days` \
           -passin "file:${FILE_ROOT_PASSWD}"

echo "Verifying the intermediate certificate..."
openssl x509 -in "${ROOT_DIR}/certs/intermed-ca.${ROOT_DOMAIN}.pem" \
             -noout \
             -text \
             -certopt no_version,no_pubkey,no_sigdump \
             -nameopt multiline

cp "${ROOT_DIR}/certs/intermed-ca.${ROOT_DOMAIN}.pem" "${INTERMED_CRT_FILE}"
echo "Duplicated Intermediate Certificate to ${INTERMED_CRT_FILE}"

cp "${INTERMED_CRT_FILE}" "${BASE_DIR}/certificates/Intermediate_Certificate_Authority.${ROOT_DOMAIN}.crt"
echo "Copied $(basename "${INTERMED_CRT_FILE}") into ${BASE_DIR}/certificates"

cat "${INTERMED_CRT_FILE}" "${ROOT_CRT_FILE}" > "${BASE_DIR}/certificates/${ROOT_DOMAIN}.ca-bundle.crt"

openssl verify -verbose \
               -CAfile "${ROOT_CRT_FILE}" \
               "${BASE_DIR}/certificates/${ROOT_DOMAIN}.ca-bundle.crt"
echo "Verifed the intermediate certificate against the root certificate"

openssl ca -gencrl \
           -out "${INTERMED_CRL_FILE}" \
           -passin "file:${FILE_INTERMED_PASSWD}"
echo "Generated certificate revoke list (CRL) for the intermediate certificate at ${INTERMED_CRL_FILE}"

echo "We recommend that you copy these into /etc/ssl/certs..."
echo
echo "  sudo cp ${ROOT_CRT_FILE} /etc/ssl/certs/$(basename "${ROOT_CRT_FILE}")"
echo "  sudo cp ${INTERMED_CRT_FILE} /etc/ssl/certs/$(basename "${INTERMED_CRT_FILE}")"
echo "  sudo update-ca-certificates"
echo 

unset OPENSSL_CONF


