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

echo
echo "[Root Certificate Authority]"

cd "${ROOT_DIR}"

mkdir -p "${ROOT_DIR}/certreqs" 
echo "Directory ${ROOT_DIR}/certreqs created!"

mkdir -p "${ROOT_DIR}/certs"
echo "Directory ${ROOT_DIR}/certs created!"

mkdir -p "${ROOT_DIR}/crl"
echo "Directory ${ROOT_DIR}/crl created!"

mkdir -p "${ROOT_DIR}/newcerts"
echo "Directory ${ROOT_DIR}/newcerts created!"

mkdir -p "${ROOT_DIR}/private"
echo "Directory ${ROOT_DIR}/private created!"

chmod 0700 private
echo

declare -a domains
declare domain_break_me
declare permitted_domain
declare domain_choice
declare to_delete_domain_idx
declare -a tmp_domains
declare confirm_delete_domains
declare -i DNSIDX
declare domain_looks_good
while true; do
  domains=("${ROOT_DOMAIN}")
  while true; do
    echo "List of Permitted Domains for Root CA: ${domains[*]}"
    echo
    echo "Choose an option:"
    echo "1. Add New DNS Entry"
    echo "2. Remove DNS Entry"
    echo "3. Clear All DNS Entries"
    echo "4. Done adding DNS Entries [exit loop and continue]"
    read -r -p "Choose an option [1|2|3|4]: " domain_choice
    echo
    case "${domain_choice}" in
      [1]*) 
        while true; do 
          read -r -p "Enter New DNS Entry (space separated): " permitted_domain
          permitted_domain=${permitted_domain// /,}
          IFS=',' read -ra NEW_DOMAINS_PLAIN <<< "$permitted_domain"
          valid_domain=true
          for item in "${NEW_DOMAINS_PLAIN[@]}"; do
            if [[ ! $item =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then 
              echo "Invalid entry! Rejected '${item}'."
              valid_domain=false
              break
            fi
          done
          if [ "$valid_domain" = true ]; then
            domains+=("${NEW_DOMAINS_PLAIN[@]}")
            echo
          fi
          break
        done
        ;;
      [2]*)
        domain_break_me=0 # a way to get out of the parent loop
        while true; do
          DNSIDX=1
          echo "Choose a DNS Entry to delete: "
          echo "0. Don't delete any entry."
          for item in "${domains[@]}"; do
            echo "${DNSIDX}. ${item}"
            ((DNSIDX++))
          done
          echo "${DNSIDX}. Done adding DNS Entries [exit loop and continue]"
          read -r -p "Choose an option: [0-${DNSIDX}]: " to_delete_domain_idx
          echo
          if [[ "${to_delete_domain_idx}" == "0" || "${to_delete_domain_idx}" == "" ]]; then
            break
          fi
          if [[ "${to_delete_domain_idx}" == "${DNSIDX}" ]]; then
            domain_break_me=1 # also break out of the parent loop
            break
          fi
          if [[ $to_delete_domain_idx =~ ^[0-9]+$ ]]; then
            DNSIDX=1
            tmp_domains=()
            for item in "${domains[@]}"; do
              if [[ $DNSIDX -ne $to_delete_domain_idx ]]; then
                tmp_domains+=("${item}")
              fi
              ((DNSIDX++))
            done
            domains=("${tmp_domains[@]}")
            break
          else
            echo "Invalid option. Please try again."
            continue
          fi
        done
        if [[ "${domain_break_me}" == "1" ]]; then # perform the break out of the parent loop
          break
        fi
        ;;
      [3]*)
        echo "Pending Delete DNS Entries: ${domains[*]}"
        read -r -p "Are you sure you want to delete all DNS Entries? [y|n*]: " confirm_delete_domains
        echo
        if [[ "${confirm_delete_domains}" == "" || "$confirm_delete_domains" =~ ^[Nn] ]]; then
          continue
        else
          domains=()
          continue
        fi
        ;;
      *)
        if [[ ${#domains[@]} -eq 0 ]]; then
          echo "Can't create a CA with no DNS entries."
          echo
          continue
        else
          break
        fi
        ;;
    esac
  done

  echo "DNS entries for [name_constraints]: ${domains[*]}"
  echo
  read -r -p "Does this look good? [y|n*]: " domain_looks_good
  if [[ "${domain_looks_good}" == "" || "${domain_looks_good}" =~ ^[Nn] ]]; then
    echo "Let's try that entire process again, shall we?"
    echo
    domains=()
    continue
  else
    echo
    echo "Preparing to issue a new signed certificate with the domains:"
    for item in "${domains[@]}"; do
      echo "- ${item}"
    done
    echo
    break
  fi
done

touch "${ROOT_DIR}/private/.rnd"
echo "File ${ROOT_DIR}/private/.rnd created!"

declare -i counter
{
  echo "RANDFILE                          = ${ROOT_DIR}/private/.rnd"
  echo '[ ca ]'
  echo 'default_ca                        = root_ca'
  echo '' 
  echo '[ root_ca ]'
  echo "dir                               = ${ROOT_DIR}"
  echo 'certs                             = $dir/certs'
  echo 'crl_dir                           = $dir/crl'
  echo 'new_certs_dir                     = $dir/newcerts'
  echo "database                          = \$dir/${ROOT_DOMAIN}.root-ca.index"
  echo "serial                            = \$dir/${ROOT_DOMAIN}.root-ca.serial"
  echo "rand_serial                       = yes"
  echo '' 
  echo "certificate                       = \$dir/${ROOT_DOMAIN}.root-ca.cert.pem"
  echo "private_key                       = \$dir/private/${ROOT_DOMAIN}.root-ca.key.pem"
  echo '' 
  echo "crlnumber                         = \$dir/crl/${ROOT_DOMAIN}.root-ca.crlnum"
  echo "crl                               = \$dir/crl/${ROOT_DOMAIN}.root-ca.crl"
  echo 'crl_extensions                    = crl_ext'
  echo 'default_crl_days                  = 180'
  echo '' 
  echo 'default_md                        = sha256'
  echo '' 
  echo 'name_opt                          = multiline, align'
  echo 'cert_opt                          = no_pubkey'
  echo 'default_days                      = 3333'
  echo 'preserve                          = no'
  echo 'policy                            = policy_strict'
  echo 'copy_extensions                   = copy'
  echo 'email_in_dn                       = no'
  echo 'unique_subject                    = no'
  echo '' 
  echo '[policy_strict]'
  echo 'countryName                       = optional'
  echo 'stateOrProvinceName               = optional'
  echo 'localityName                      = optional'
  echo 'organizationName                  = optional'
  echo 'emailAddress                      = optional'
  echo 'organizationalUnitName            = optional'
  echo 'commonName                        = supplied'
  echo '' 
  echo '[ req ]'
  echo 'default_bits                      = 4096'
  echo "default_keyfile                   = private/${ROOT_DOMAIN}.root-ca.key.pem"
  echo 'encrypt_key                       = yes'
  echo 'default_md                        = sha256'
  echo 'string_mask                       = utf8only'
  echo 'utf8                              = yes'
  echo 'prompt                            = no'
  echo 'req_extensions                    = root-ca_req_ext'
  echo 'distinguished_name                = distinguished_name'
  echo 'subjectAltName                    = @subject_alt_name'
  echo '' 
  echo '[ root-ca_req_ext ]'
  echo 'subjectKeyIdentifier              = hash'
  echo 'subjectAltName                    = @subject_alt_name'
  echo '' 
  echo '[ distinguished_name ]'
  echo "organizationName                  = ${CA_NAME}"
  echo "commonName                        = ${ROOT_DOMAIN}"
  echo "emailAddress                      = certmaster@${ROOT_DOMAIN}"
  echo '' 
  echo '' 
  echo '[ root-ca_ext ]'
  echo 'basicConstraints                  = critical, CA:true'
  echo 'keyUsage                          = critical, keyCertSign, cRLSign, digitalSignature'
  echo 'nameConstraints                   = critical, @name_constraints'
  echo 'subjectKeyIdentifier              = hash'
  echo 'subjectAltName                    = @subject_alt_name'
  echo 'authorityKeyIdentifier            = keyid:always'
  echo 'issuerAltName                     = issuer:copy'
  echo 'authorityInfoAccess               = @auth_info_access'
  echo 'crlDistributionPoints             = @crl_dist'
  echo '' 
  echo '[ intermed-ca_ext ]'
  echo 'basicConstraints                  = critical, CA:true, pathlen:0'
  echo 'keyUsage                          = critical, keyCertSign, cRLSign, digitalSignature'
  echo 'subjectKeyIdentifier              = hash'
  echo 'subjectAltName                    = @subject_alt_name'
  echo 'authorityKeyIdentifier            = keyid:always'
  echo 'issuerAltName                     = issuer:copy'
  echo 'authorityInfoAccess               = @auth_info_access'
  echo 'crlDistributionPoints             = @crl_dist'
  echo '' 
  echo '[ crl_ext ]'
  echo 'authorityKeyIdentifier            = keyid:always'
  echo 'issuerAltName                     = issuer:copy'
  echo '' 
  echo '[ subject_alt_name ]'
  echo "URI                               = http://ca.${ROOT_DOMAIN}"
  echo "email                             = certmaster@${ROOT_DOMAIN}"
  echo '' 
  echo '[ auth_info_access ]'
  echo "caIssuers;URI                     = http://ca.${ROOT_DOMAIN}/certs/Root_CA.crt"
  echo '' 
  echo '[ crl_dist ]'
  echo "URI.1                             = http://ca.${ROOT_DOMAIN}/crl/Root_CA.crl"
  echo '' 
  echo '[ name_constraints ]'
  counter=1
  for item in "${domains[@]}"; do
    echo "permitted;DNS.${counter}          = ${item}"
    ((counter++))
  done
  echo "permitted;DNS.${counter}          = lan"
  counter=1
  for item in "${domains[@]}"; do
    echo "permitted;email.${counter}        = ${item}"
    ((counter++))
  done
  echo "permitted;email.${counter}        = lan"
} | tee -a "${ROOT_CNF_FILE}" > /dev/null
echo "File ${ROOT_CNF_FILE} created!"

echo
echo "[Intermediate Certificate Authority]"

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

cd "${INTERMED_DIR}"
mkdir -p "${INTERMED_DIR}/certreqs" 
echo "Directory ${INTERMED_DIR}/certreqs created!"

mkdir -p "${INTERMED_DIR}/certs"
echo "Directory ${INTERMED_DIR}/certs created!"

mkdir -p "${INTERMED_DIR}/crl"
echo "Directory ${INTERMED_DIR}/crl created!"

mkdir -p "${INTERMED_DIR}/newcerts"
echo "Directory ${INTERMED_DIR}/newcerts created!"

mkdir -p "${INTERMED_DIR}/private"
echo "Directory ${INTERMED_DIR}/private created!"

chmod 0700 private

touch "${INTERMED_DIR}/private/.rnd"
echo "File ${INTERMED_DIR}/private/.rnd created!"

echo
{
  echo '[ ca ]' 
  echo 'default_ca              = intermed_ca' 
  echo '' 
  echo '[ intermed_ca ]' 
  echo "dir                     = ${INTERMED_DIR}" 
  echo 'certs                   = $dir/certs'
  echo "serial                  = \$dir/${ROOT_DOMAIN}.intermed-ca.serial"
  echo "database                = \$dir/${ROOT_DOMAIN}.intermed-ca.index"
  echo 'new_certs_dir           = $dir/newcerts'
  echo "certificate             = \$dir/${ROOT_DOMAIN}.intermed-ca.cert.pem"
  echo "private_key             = \$dir/private/${ROOT_DOMAIN}.intermed-ca.key.pem"
  echo 'default_days            = 3333'
  echo "crl                     = \$dir/crl/${ROOT_DOMAIN}.intermed-ca.crl"
  echo 'crl_dir                 = $dir/crl'
  echo "crlnumber               = \$dir/crl/${ROOT_DOMAIN}.intermed-ca.crlnum"
  echo 'name_opt                = multiline, align'
  echo 'cert_opt                = no_pubkey'
  echo 'copy_extensions         = copy'
  echo 'crl_extensions          = crl_ext'
  echo 'default_crl_days        = 36'
  echo 'default_md              = sha256'
  echo 'preserve                = no'
  echo 'email_in_dn             = no'
  echo 'policy                  = policy'
  echo 'unique_subject          = no'
  echo ''
  echo '[policy]'
  echo 'countryName             = optional'
  echo 'stateOrProvinceName     = optional'
  echo 'localityName            = optional'
  echo 'organizationName        = supplied'
  echo 'organizationalUnitName  = optional'
  echo 'commonName              = supplied'
  echo ''
  echo '[ user_policy ]'
  echo 'countryName             = supplied'
  echo 'stateOrProvinceName     = optional '
  echo 'localityName            = supplied'
  echo 'organizationName        = optional'
  echo 'organizationalUnitName  = optional'
  echo 'commonName              = supplied'
  echo 'emailAddress            = supplied'
  echo ''
  echo '[ req ]'
  echo 'default_bits            = 4096'
  echo "default_keyfile         = private/${ROOT_DOMAIN}.intermed-ca.key.pem"
  echo 'encrypt_key             = yes'
  echo 'default_md              = sha256'
  echo 'string_mask             = utf8only'
  echo 'utf8                    = yes'
  echo 'prompt                  = no'
  echo 'req_extensions          = req_ext'
  echo 'distinguished_name      = distinguished_name'
  echo 'subjectAltName          = @subject_alt_name'
  echo ''
  echo '[ req_ext ]'
  echo 'subjectKeyIdentifier    = hash'
  echo 'subjectAltName          = @subject_alt_name'
  echo ''
  echo '[ distinguished_name ]'
  echo "organizationName        = ${CA_NAME}"
  echo "commonName              = ${CA_NAME} Intermediate Certificate Authority"
  echo ''
  echo '[ server_ext ]'
  echo 'basicConstraints        = CA:FALSE'
  echo 'keyUsage                = critical, digitalSignature, keyEncipherment'
  echo 'extendedKeyUsage        = critical, serverAuth, clientAuth'
  echo 'subjectKeyIdentifier    = hash'
  echo 'authorityKeyIdentifier  = keyid:always'
  echo 'issuerAltName           = issuer:copy'
  echo 'authorityInfoAccess     = @auth_info_access'
  echo 'crlDistributionPoints   = crl_dist'
  echo ''
  echo '[ client_ext ]'
  echo 'basicConstraints        = CA:FALSE'
  echo 'keyUsage                = critical, digitalSignature'
  echo 'extendedKeyUsage        = critical, clientAuth'
  echo 'subjectKeyIdentifier    = hash'
  echo 'authorityKeyIdentifier  = keyid:always'
  echo 'issuerAltName           = issuer:copy'
  echo 'authorityInfoAccess     = @auth_info_access'
  echo 'crlDistributionPoints   = crl_dist'
  echo ''
  echo '[ user_ext ]'
  echo 'basicConstraints        = CA:FALSE'
  echo 'keyUsage                = critical, digitalSignature, keyEncipherment'
  echo 'extendedKeyUsage        = critical, clientAuth, emailProtection'
  echo 'subjectKeyIdentifier    = hash'
  echo 'authorityKeyIdentifier  = keyid:always'
  echo 'issuerAltName           = issuer:copy'
  echo 'authorityInfoAccess     = @auth_info_access'
  echo 'crlDistributionPoints   = crl_dist'
  echo ''
  echo '[ crl_ext ]'
  echo 'authorityKeyIdentifier  = keyid:always'
  echo 'issuerAltName           = issuer:copy'
  echo ''
  echo '[ subject_alt_name ]' 
  echo "URI                     = http://ca.${ROOT_DOMAIN}/"
  echo "email                   = certmaster@${ROOT_DOMAIN}"
  echo ''
  echo '[ auth_info_access ]'
  echo "caIssuers;URI           = http://ca.${ROOT_DOMAIN}/certs/Intermediate_Certificate_Authority.crt"
  echo ''
  echo '[ crl_dist ]'
  echo "fullname                = URI:http://ca.${ROOT_DOMAIN}/crl/Intermediate_Certificate_Authority.crl"
} | tee -a "${INTERMED_CNF_FILE}" > /dev/null
echo "File ${INTERMED_CNF_FILE} created!"

cd "${ROOT_DIR}"

echo 
echo "[Root Certificate Authority]"

touch "${ROOT_INDEX_FILE}"
echo "File ${ROOT_INDEX_FILE} created!"

echo 00 > "${ROOT_CRLNUM_FILE}"
echo "File ${ROOT_CRLNUM_FILE} created!"

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
echo "File ${FILE_ROOT_PASSWD} created!"
chmod 0400 "${FILE_ROOT_PASSWD}"
echo "File ${FILE_ROOT_PASSWD} secured!"
echo

declare SUGGEST_INTERMED_PASSWD
SUGGEST_INTERMED_PASSWD="$(generate_random_password 72)"
echo "${SUGGEST_INTERMED_PASSWD}" | tee -a "${FILE_INTERMED_PASSWD}" > /dev/null
echo "File ${FILE_INTERMED_PASSWD} created!"
chmod 0400 "${FILE_INTERMED_PASSWD}"
echo "File ${FILE_INTERMED_PASSWD} secured!"
echo

openssl rand -hex 16 > "${ROOT_SERIAL_FILE}"
echo "File ${ROOT_SERIAL_FILE} created!"

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
  echo "File ${BASE_DIR}/passwd/.root-ca.ecc-curve created!"

  case "${ROOT_ALGO_CURVE}" in
    prime256v1) 
      openssl genpkey -algorithm EC \
                      -out "${ROOT_KEY_FILE}" \
                      -pkeyopt ec_paramgen_curve:prime256v1 \
                      -aes-256-cbc \
                      -pass "file:${FILE_ROOT_PASSWD}"
      ;;
    secp384r1) 
      openssl genpkey -algorithm EC \
                      -out "${ROOT_KEY_FILE}" \
                      -pkeyopt ec_paramgen_curve:secp384r1 \
                      -aes-256-cbc \
                      -pass "file:${FILE_ROOT_PASSWD}"
      ;;
    brainpoolP512r1) 
      openssl genpkey -algorithm EC \
                      -out "${ROOT_KEY_FILE}" \
                      -pkeyopt ec_paramgen_curve:brainpoolP512r1 \
                      -aes-256-cbc \
                      -pass "file:${FILE_ROOT_PASSWD}"
      ;;
    nistp521) 
      openssl genpkey -algorithm EC \
                      -out "${ROOT_KEY_FILE}" \
                      -pkeyopt ec_paramgen_curve:secp521r1 \
                      -aes-256-cbc \
                      -pass "file:${FILE_ROOT_PASSWD}"
      ;;
    *) # ed25519 or edwards25519 
      openssl genpkey -algorithm ED25519 \
                      -out "${ROOT_KEY_FILE}" \
                      -aes-256-cbc \
                      -pass "file:${FILE_ROOT_PASSWD}"
      ;;
  esac
  echo "File ${ROOT_KEY_FILE} created!"

  openssl req -new \
              -x509 \
              -sha512 \
              -days 6273 \
              -config "${ROOT_CNF_FILE}" \
              -extensions "root-ca_ext" \
              -key "${ROOT_KEY_FILE}" \
              -out "${ROOT_CRT_FILE}" \
              -passin "file:${FILE_ROOT_PASSWD}"
  echo "File ${ROOT_CRT_FILE} created!"
else
  while true; do
    echo "Which RSA bit length shall be used for ${ROOT_DOMAIN} Root Certificate Authority? "
    echo ""
    echo "Choice  Bits  Performance  Security"
    echo "------  ----  -----------  --------"
    echo "1       2048  Excellent    Good"
    echo "2       3072  Excellent    Very good"
    echo "3       4096  Very good    Excellent"
    echo "4       8192  Slow         Excellent"
    echo ""
    read -r -p "Which bit length shall be used? [1-4]: " ROOT_BIT_LENGTH
    echo
    ROOT_BIT_LENGTH_LOWER=$(echo "${ROOT_BIT_LENGTH}" | tr '[:upper:]' '[:lower:]')
    if [[ "${ROOT_BIT_LENGTH_LOWER}" =~ ^(2048|3072|4096|8192|1|2|3|4)$ ]]; then
      case "${ROOT_BIT_LENGTH_LOWER}" in
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

  openssl genrsa -aes256 \
                 -out "${ROOT_KEY_FILE}" \
                 -passout "file:${FILE_ROOT_PASSWD}" \
                 "${ROOT_BIT_LENGTH}"
  echo "File ${ROOT_KEY_FILE} created!"

  openssl req -new \
              -sha256 \
              -x509 \
              -config "${ROOT_CNF_FILE}" \
              -extensions "root-ca_ext" \
              -key "${ROOT_KEY_FILE}" \
              -passin "file:${FILE_ROOT_PASSWD}" \
              -out "${ROOT_CRT_FILE}"
  echo "File ${ROOT_CRT_FILE} created!"
fi

chmod 0400 "${ROOT_KEY_FILE}"
echo "File ${ROOT_KEY_FILE} secured!"

openssl x509 -in "${ROOT_CRT_FILE}" \
             -noout \
             -text \
             -certopt no_version,no_pubkey,no_sigdump \
             -nameopt multiline

openssl ca -gencrl \
           -config "${ROOT_CNF_FILE}" \
           -out "${ROOT_CRL_FILE}" \
           -passin "file:${FILE_ROOT_PASSWD}"

cp "${ROOT_CRT_FILE}" "${BASE_DIR}/certificates/Root_Certificate_Authority.${ROOT_DOMAIN}.crt"
echo "File ${BASE_DIR}/certificates/Root_Certificate_Authority.${ROOT_DOMAIN}.crt created!"

unset OPENSSL_CONF

echo 
echo "[Intermediate Certificate Authority]"

cd "${INTERMED_DIR}"

export OPENSSL_CONF="${INTERMED_CNF_FILE}"

touch "${INTERMED_INDEX_FILE}"
echo "File ${INTERMED_INDEX_FILE} created!"

echo 00 > "${INTERMED_CRLNUM_FILE}"
echo "File ${INTERMED_CRLNUM_FILE} created!"

openssl rand -hex 16 > "${INTERMED_SERIAL_FILE}"
echo "File ${INTERMED_SERIAL_FILE} created!"

if grep -q "ecc" <<< "${ROOT_ALGORITHM_LOWER}"; then
  case "${ROOT_ALGORITHM_LOWER}" in
    prime256v1) 
      openssl genpkey -algorithm EC \
                      -out "${INTERMED_KEY_FILE}" \
                      -pkeyopt ec_paramgen_curve:prime256v1 \
                      -aes-256-cbc \
                      -pass "file:${FILE_INTERMED_PASSWD}"
      ;;
    secp384r1) 
      openssl genpkey -algorithm EC \
                      -out "${INTERMED_KEY_FILE}" \
                      -pkeyopt ec_paramgen_curve:secp384r1 \
                      -aes-256-cbc \
                      -pass "file:${FILE_INTERMED_PASSWD}"
      ;;
    brainpoolP512r1) 
      openssl genpkey -algorithm EC \
                      -out "${INTERMED_KEY_FILE}" \
                      -pkeyopt ec_paramgen_curve:brainpoolP512r1 \
                      -aes-256-cbc \
                      -pass "file:${FILE_INTERMED_PASSWD}"
      ;;
    nistp521) 
      openssl genpkey -algorithm EC \
                      -out "${INTERMED_KEY_FILE}" \
                      -pkeyopt ec_paramgen_curve:secp521r1 \
                      -aes-256-cbc \
                      -pass "file:${FILE_INTERMED_PASSWD}"
      ;;
    *) # ed25519 or edwards25519 
      openssl genpkey -algorithm ED25519 \
                      -out "${INTERMED_KEY_FILE}" \
                      -aes-256-cbc \
                      -pass "file:${FILE_INTERMED_PASSWD}"
      ;;
  esac
  echo "File ${INTERMED_KEY_FILE} created!"

  openssl req -new \
              -sha512 \
              -config "${INTERMED_CNF_FILE}" \
              -key "${INTERMED_KEY_FILE}" \
              -out "${INTERMED_CSR_FILE}"  \
              -passin "file:${FILE_INTERMED_PASSWD}"
  echo "File ${INTERMED_CSR_FILE} created!"
else
  openssl genrsa -aes256 \
                 -out "${INTERMED_KEY_FILE}" \
                 -passout "file:${FILE_INTERMED_PASSWD}" \
                 "${ROOT_BIT_LENGTH}"
  echo "File ${INTERMED_KEY_FILE} created!"

  openssl req -new \
              -sha256 \
              -config "${INTERMED_CNF_FILE}" \
              -key "${INTERMED_KEY_FILE}" \
              -passin "file:${FILE_INTERMED_PASSWD}" \
              -out "${INTERMED_CSR_FILE}"
  echo "File ${INTERMED_CSR_FILE} created!"
fi

chmod 0400 "${INTERMED_KEY_FILE}"
echo "File ${INTERMED_KEY_FILE} secured!"

declare INTERMED_CSR_IN_ROOT_DIR
INTERMED_CSR_IN_ROOT_DIR="${ROOT_DIR}/certreqs/$(basename "${INTERMED_CSR_FILE}")"

cp "${INTERMED_CSR_FILE}" "${INTERMED_CSR_IN_ROOT_DIR}"
echo "Copied $(basename "${INTERMED_CSR_FILE}") into ${ROOT_DIR}/certreqs"

unset OPENSSL_CONF

declare INTERMED_CRT_IN_ROOT_DIR
INTERMED_CRT_IN_ROOT_DIR="${ROOT_DIR}/certs/intermed-ca.${ROOT_DOMAIN}.pem"

cd "${ROOT_DIR}"

export OPENSSL_CONF="${ROOT_CNF_FILE}"

echo "Signing the intermediate certificate with the Root CA..."
openssl ca -config "${ROOT_CNF_FILE}" \
           -in "${INTERMED_CSR_IN_ROOT_DIR}" \
           -out "${INTERMED_CRT_IN_ROOT_DIR}" \
           -extensions "intermed-ca_ext" \
           -startdate `date +%y%m%d000000Z -u -d -1day` \
           -enddate `date +%y%m%d000000Z -u -d +17years+17days` \
           -passin "file:${FILE_ROOT_PASSWD}"
echo "File ${INTERMED_CRT_IN_ROOT_DIR} created!"

echo "Verifying the intermediate certificate..."
openssl x509 -in "${INTERMED_CRT_IN_ROOT_DIR}" \
             -noout \
             -text \
             -certopt no_version,no_pubkey,no_sigdump \
             -nameopt multiline

cp "${INTERMED_CRT_IN_ROOT_DIR}" "${INTERMED_CRT_FILE}"
echo "File ${INTERMED_CRT_FILE} created!"

cp "${INTERMED_CRT_FILE}" "${BASE_DIR}/certificates/Intermediate_Certificate_Authority.${ROOT_DOMAIN}.crt"
echo "File ${BASE_DIR}/certificates/Intermediate_Certificate_Authority.${ROOT_DOMAIN}.crt created!"

cat "${INTERMED_CRT_FILE}" "${ROOT_CRT_FILE}" > "${BASE_DIR}/certificates/${ROOT_DOMAIN}.ca-bundle.crt"
echo "File ${BASE_DIR}/certificates/${ROOT_DOMAIN}.ca-bundle.crt created!"

echo "Attempting to verify the newly issued Intermediate Certificate against the Root Authority..."
openssl verify -verbose \
               -CAfile "${ROOT_CRT_FILE}" \
               "${INTERMED_CRT_FILE}"

openssl verify -verbose \
               -CAfile "${ROOT_CRT_FILE}" \
               "${BASE_DIR}/certificates/${ROOT_DOMAIN}.ca-bundle.crt"
echo "Verifed the intermediate certificate against the root certificate"

openssl ca -gencrl \
           -config "${INTERMED_CNF_FILE}" \
           -out "${INTERMED_CRL_FILE}" \
           -passin "file:${FILE_INTERMED_PASSWD}"
echo "File ${INTERMED_CRL_FILE} created!"

echo "We recommend that you copy these into /etc/ssl/certs..."
echo
echo "  sudo cp ${ROOT_CRT_FILE} /etc/ssl/certs/$(basename "${ROOT_CRT_FILE}")"
echo "  sudo cp ${INTERMED_CRT_FILE} /etc/ssl/certs/$(basename "${INTERMED_CRT_FILE}")"
echo "  sudo update-ca-certificates"
echo 

unset OPENSSL_CONF
