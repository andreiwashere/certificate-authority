#!/bin/bash

function safe_exit(){
  local msg="${1}"
  echo "${msg}"
  exit 1
}

declare CA_DIR
: "${CA_DIR:=${1}}"
CA_DIR=$(realpath "${CA_DIR}")
declare -i RETRIES=0

if [[ "${CA_DIR}" == "" ]] || [[ "${CA_DIR}" == "." ]] || [[ ! -d "${CA_DIR}" ]]; then
  while true; do
    read -r -t 30 -p "Enter the CA's root directory: " CA_DIR
    echo
    if [[ "${CA_DIR}" == "" ]]; then
      ((RETRIES++))
      if (( RETRIES >= 6 )); then
        safe_exit "Timed out."
      fi
    elif [[ ! -d "${CA_DIR}/intermed-ca" || ! -d "${CA_DIR}/passwd" || ! -d "${CA_DIR}/tmp" ]]; then
      echo "Invalid CA directory path provided."
      continue
    else
      break
    fi
  done
fi

echo "CA_DIR = ${CA_DIR}"

declare CRT_LABEL
while true; do
  read -r -p "Enter the label for this new certificate (eg: redis): " CRT_LABEL
  echo
  if [ "${CRT_LABEL}" == "" ]; then
    echo "Invalid label provided."
    echo
    continue
  elif [[ ! $CRT_LABEL =~ ^[A-Za-z0-9_-]{3,69}$ ]]; then
    echo "Failed to validate the label. Valid charaters A-Z, 0-9 and - or _ (min 3 chars; max 69 chars)."
    echo
    continue
  elif [[ -f "${CA_DIR}/tmp/${CRT_LABEL}/${CRT_LABEL}.crt" ]]; then
    echo "There appears to be a certificate already issued for this label ${CRT_LABEL}."
    cat "${CA_DIR}/tmp/${CRT_LABEL}/${CRT_LABEL}.crt"
    echo
    continue
  else
    break
  fi
done

function verify_ca_compatibility() {
  local file_root_crt="$1"
  local file_intermed_crt="$2"
  local requested_domain="$3"

  # Extract name constraints from the root certificate
  local root_constraints
  root_constraints=$(openssl x509 -in "$file_root_crt" -text -noout | grep "DNS:" | sed 's/DNS://g' | tr -d ' ')

  # Extract name constraints from the intermediate certificate
  local intermed_constraints
  intermed_constraints=$(openssl x509 -in "$file_intermed_crt" -text -noout | grep "DNS:" | sed 's/DNS://g' | tr -d ' ')

  # If there are no constraints in the root or intermediate CAs, return success
  if [[ -z "$root_constraints" && -z "$intermed_constraints" ]]; then
    return 0
  fi

  # Check if the requested domain matches or is a subdomain of any of the constrained domains
  IFS=',' read -ra ROOT_CONSTRAINTS_ARRAY <<< "$root_constraints"
  IFS=',' read -ra INTERMED_CONSTRAINTS_ARRAY <<< "$intermed_constraints"

  for constraint in "${ROOT_CONSTRAINTS_ARRAY[@]}" "${INTERMED_CONSTRAINTS_ARRAY[@]}"; do
    if [[ "$requested_domain" == "$constraint" || "$requested_domain" == *".$constraint" ]]; then
      return 0
    fi
  done

  # If we reach here, no match was found
  return 1
}

declare WORKSPACE
WORKSPACE="${CA_DIR}/tmp/${CRT_LABEL}"

declare FILE_CNF
FILE_CNF="${WORKSPACE}/${CRT_LABEL}.cnf"

declare FILE_CSR
FILE_CSR="${WORKSPACE}/${CRT_LABEL}.csr"

declare FILE_KEY
FILE_KEY="${WORKSPACE}/${CRT_LABEL}.key"

declare FILE_CRT
FILE_CRT="${WORKSPACE}/${CRT_LABEL}.crt"

declare FILE_CA_CRT
FILE_CA_CRT="${WORKSPACE}/${CRT_LABEL}.ca-bundle.crt"

declare FILE_INTERMED_PASSWD
FILE_INTERMED_PASSWD=$(find "${CA_DIR}/passwd" -maxdepth 1 -type f -name ".intermed-ca.*.passwd")
echo "FILE_INTERMED_PASSWD = ${FILE_INTERMED_PASSWD}"
if [[ ! -f "${FILE_INTERMED_PASSWD}" || ! -r "${FILE_INTERMED_PASSWD}" ]]; then
 safe_exit "Permission denied [PASSWD] to use the intermediate certificate authority."
fi

declare INTERMED_CNF_FILE
INTERMED_CNF_FILE=$(find "${CA_DIR}/intermed-ca" -maxdepth 1 -type f -name "*.intermed-ca.cnf")
if [[ ! -f "${INTERMED_CNF_FILE}" || ! -r "${INTERMED_CNF_FILE}" ]]; then
  safe_exit "Permission denied [CNF] to use the intermediate certificate authority."
fi

declare INTERMED_CRT_FILE
INTERMED_CRT_FILE=$(find "${CA_DIR}/intermed-ca" -maxdepth 1 -type f -name "*.intermed-ca.cert.pem")
if [[ ! -f "${INTERMED_CRT_FILE}" || ! -r "${INTERMED_CRT_FILE}" ]]; then
  safe_exit "Permission denied [CRT] to use the intermediate certificate authority."
fi

declare ROOT_CRT_FILE
ROOT_CRT_FILE=$(find "${CA_DIR}/root-ca" -maxdepth 1 -type f -name "*.root-ca.cert.pem")
if [[ ! -f "${ROOT_CRT_FILE}" || ! -r "${ROOT_CRT_FILE}" ]]; then
  safe_exit "Permission denied [CRT] to use the root certificate authority."
fi

declare INTERMED_SERIAL_FILE
INTERMED_SERIAL_FILE=$(find "${CA_DIR}/intermed-ca" -maxdepth 1 -type f -name "*.intermed-ca.serial")
if [[ ! -f "${INTERMED_SERIAL_FILE}" || ! -r "${INTERMED_SERIAL_FILE}" ]]; then
  safe_exit "Permission denied [SERIAL] to use the intermediate certificate authority."
fi

declare CA_BUNDLE_FILE
CA_BUNDLE_FILE=$(find "${CA_DIR}/certificates" -maxdepth 1 -type f -name "*.ca-bundle.crt")
if [[ ! -f "${CA_BUNDLE_FILE}" || ! -r "${CA_BUNDLE_FILE}" ]]; then
  safe_exit "Permission denied [CA_BUNDLE] to use the intermediate certificate authority."
fi

mkdir -p "${WORKSPACE}"

declare -i DNSIDX
declare -a domains
declare -a tmp_domains
declare confirm_delete_domains
declare domain_choice
declare domain_break_me
declare domain_looks_good
declare permitted_domain
declare to_delete_domain_idx
declare IFS
declare valid_domain
declare -a NEW_DOMAINS_PLAIN
while true; do
  domains=()
  while true; do
    echo "List of DNS for certificate: ${domains[*]}"
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
          read -r -p "Enter New DNS Entry: " permitted_domain
          permitted_domain=${permitted_domain// /,}
          IFS=',' read -ra NEW_DOMAINS_PLAIN <<< "$permitted_domain"
          valid_domain=true
          for item in "${NEW_DOMAINS_PLAIN[@]}"; do
            if [[ ! $item =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then 
              echo "Invalid entry! Rejected '${item}'."
              valid_domain=false
              break
            else 
              if ! verify_ca_compatibility "$ROOT_CRT_FILE" "$INTERMED_CRT_FILE" "${item}"; then
                echo "[WARNING] CA has rejected your request for ${item}"
                echo
                valid_domain=false
                break
              fi
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
          echo "Can't create a certificate with no DNS entries."
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

declare -i IPIDX
declare -a ips
declare -a tmp_ips
declare confirm_delete_ips
declare input_ips
declare ip_break_me
declare ip_choice
declare ips_looks_good
declare permitted_ip
declare to_delete_ip_idx
declare -a valid_ips
while true; do
  ips=()
  while true; do
    echo "List of SAN IPs: ${ips[*]}"
    echo
    echo "Choose an option:"
    echo "1. Add New IP Entry"
    echo "2. Remove IP Entry"
    echo "3. Clear All IP Entries"
    echo "4. Done adding IP Entries [exit loop and continue]"
    read -r -p "Choose an option [1|2|3|4]: " ip_choice
    echo
    case "${ip_choice}" in
      [1]*) 
        while true; do 
          read -r -p "Enter New IP Entries (separated by spaces or commas): " input_ips
          IFS=', ' read -ra permitted_ips <<< "$input_ips"
          
          valid_ips=()
          for ip in "${permitted_ips[@]}"; do
            if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ && "$ip" != "0.0.0.0" ]]; then 
              valid_ips+=("$ip")
            else
              echo "Invalid entry! Rejected '$ip'."
            fi
          done

          if (( ${#valid_ips[@]} > 0 )); then
            ips+=("${valid_ips[@]}")
            echo "Added the following valid IPs:"
            for ip in "${valid_ips[@]}"; do
                echo "$ip"
            done
            break
          else
            echo "No valid IPs provided. Try again."
          fi
        done
        ;;
      [2]*)
        ip_break_me=0 # a way to get out of the parent loop
        while true; do
          IPIDX=1
          echo "Choose a IP Entry to delete: "
          echo "0. Don't delete any entry."
          for item in "${ips[@]}"; do
            echo "${IPIDX}. ${item}"
            ((IPIDX++))
          done
          echo "${IPIDX}. Done adding IP Entries [exit loop and continue]"
          read -r -p "Choose an option: [0-${IPIDX}]: " to_delete_ip_idx
          echo
          if [[ "${to_delete_ip_idx}" == "0" || "${to_delete_ip_idx}" == "" ]]; then
            break
          fi
          if [[ "${to_delete_ip_idx}" == "${IPIDX}" ]]; then
            ip_break_me=1 # also break out of the parent loop
            break
          fi
          if [[ $to_delete_ip_idx =~ ^[0-9]+$ ]]; then
            IPIDX=1
            tmp_ips=()
            for item in "${ips[@]}"; do
              if [[ $IPIDX -ne $to_delete_ip_idx ]]; then
                tmp_ips+=("${item}")
              fi
              ((IPIDX++))
            done
            ips=("${tmp_ips[@]}")
            break
          else
            echo "Invalid option. Please try again."
            continue
          fi
        done
        if [[ "${ip_break_me}" == "1" ]]; then # perform the break out of the parent loop
          break
        fi
        ;;
      [3]*)
        echo "Pending Delete IP Entries: ${ips[*]}"
        read -r -p "Are you sure you want to delete all IP Entries? [y|n*]: " confirm_delete_ips
        echo
        if [[ "${confirm_delete_ips}" == "" || "$confirm_delete_ips" =~ ^[Nn] ]]; then
          continue
        else
          ips=()
          continue
        fi
        ;;
      *)
        break
        ;;
    esac
  done

  echo "IP entries for [name_constraints]: ${ips[*]}"
  echo
  read -r -p "Does this look good? [y|n*]: " ips_looks_good
  if [[ "${ips_looks_good}" == "" || "${ips_looks_good}" =~ ^[Nn] ]]; then
    echo "Let's try that entire process again, shall we?"
    echo
    ips=()
    continue
  else
    echo
    echo "Preparing to issue a new signed certificate with the SAN IPs:"
    for item in "${ips[@]}"; do
      echo "- ${item}"
    done
    echo
    break
  fi
done

declare -i DAYS
while true; do
  read -r -p "How many days do you want the certificate to be valid? " DAYS
  echo
  if [[ $DAYS -gt 3 && $DAYS -lt 9630 ]]; then
    break
  else
    echo "Invalid duration in days [valid: 3 days to 9630 days (~26.37 years)]."
    echo
    continue
  fi
done

touch "${FILE_CNF}" || safe_exit "ERROR: Cannot create ${FILE_CNF}."
declare -i counter
{
  echo '[req]'
  echo "days                    = ${DAYS}"
  echo 'default_bits            = 4096'
  echo 'default_md              = sha256'
  echo "default_keyfile         = ${FILE_KEY}"
  echo 'distinguished_name      = req_distinguished_name'
  echo 'x509_extensions         = v3_ca'
  echo 'req_extensions          = v3_req'
  echo ''
  echo '[ req_distinguished_name ]'
  echo 'C                       = Country (2 Letter Code)'
  echo 'ST                      = State (2 Letter Code)'
  echo 'L                       = Locality (eg City)'
  echo 'O                       = Organization (eg Company Name)'
  echo 'OU                      = Organizational Unit (eg Website)'
  echo 'emailAddress            = Email Address'
  echo 'CN                      = Common Name'
  echo ''
  echo '[ v3_ca ]'
  echo 'subjectAltName          = @alt_names'
  echo 'issuerAltName           = issuer:copy'
  echo ''
  echo '[ v3_req ]'
  echo 'extendedKeyUsage        = serverAuth, clientAuth, codeSigning, emailProtection'
  echo 'basicConstraints        = CA:FALSE'
  echo 'keyUsage                = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment'
  echo 'subjectAltName          = @alt_names'
  echo ''
  echo '[ alt_names ]'
  counter=1
  for item in "${domains[@]}"; do
    echo "DNS.${counter} = ${item}"
    ((counter++))
  done
  counter=1
  for item in "${ips[@]}"; do
    echo "IP.${counter} = ${item}"
    ((counter++))
  done
} | tee -a "${FILE_CNF}" > /dev/null

declare ALGORITHM
declare ALGORITHM_LOWER
declare ALGO_CURVE
declare ALGO_CURVE_LOWER
declare BIT_LENGTH
declare BIT_LENGTH_LOWER
while true; do
  read -r -p "Which encryption algorithm shall we use? [rsa|ecc]: " ALGORITHM
  echo
  ALGORITHM_LOWER=$(echo "${ALGORITHM}" | tr '[:upper:]' '[:lower:]')
  if [[ "${ALGORITHM_LOWER}" =~ ^(ecc|rsa)$ ]]; then
    break
  else
    echo "Invalid encryption algorithm. Please choose from RSA or ECC."
  fi
done

if grep -q "ecc" <<< "${ALGORITHM_LOWER}"; then

  while true; do
    echo "Which Elliptic Curve (EC) shall we use? "
    echo
    echo "Choice  Curve           Field Size  Security   Performance"
    echo "------  -----           ----------  --------   -----------"
    echo "1       prime256v1      256 bits    Good       Good"
    echo "2       secp384r1       384 bits    Very good  Good"
    echo "3       brainpoolP512r1 512 bits    Excellent  Slow"
    echo "4       nistp521        521 bits    Excellent  Slow"
    echo "5       edwards25519    255 bits    Excellent  Fast"
    echo
    read -r -p "Which curve do you want to use? [1-5] " ALGO_CURVE
    echo
    ALGO_CURVE_LOWER=$(echo "${ALGO_CURVE}" | tr '[:upper:]' '[:lower:]')
    if [[ "${ALGO_CURVE_LOWER}" =~ ^(prime256v1|secp384r1|brainpoolP512r1|nistp521|edwards25519|1|2|3|4|5)$ ]]; then
      case "${ALGO_CURVE_LOWER}" in
        1) ALGO_CURVE="prime256v1";;
        2) ALGO_CURVE="secp384r1";;
        3) ALGO_CURVE="brainpoolP512r1";;
        4) ALGO_CURVE="nistp521";;
        5) ALGO_CURVE="edwards25519";;
        *) ALGO_CURVE="${ALGO_CURVE_LOWER}";;
      esac
      break
    else
      echo "Invalid curve selected. Please try again."
    fi
  done

  case "${ALGO_CURVE}" in
    prime256v1) 
      openssl genpkey -algorithm EC -out "${FILE_KEY}" -pkeyopt ec_paramgen_curve:prime256v1
      ;;
    secp384r1) 
      openssl genpkey -algorithm EC -out "${FILE_KEY}" -pkeyopt ec_paramgen_curve:secp384r1
      ;;
    brainpoolP512r1) 
      openssl genpkey -algorithm EC -out "${FILE_KEY}" -pkeyopt ec_paramgen_curve:brainpoolP512r1
      ;;
    nistp521) 
      openssl genpkey -algorithm EC -out "${FILE_KEY}" -pkeyopt ec_paramgen_curve:secp521r1
      ;;
    *) # ed25519 or edwards25519 
      openssl genpkey -algorithm ED25519 -out "${FILE_KEY}"
      ;;
  esac
  echo "File ${FILE_KEY} created!"

  openssl req -new -sha512 -config "${FILE_CNF}" -key "${FILE_KEY}" -out "${FILE_CSR}"
  echo "File ${FILE_CSR} created!"
else
  while true; do
    echo "Which RSA bit length shall we use? "
    echo ""
    echo "Choice  Bits  Performance  Security"
    echo "------  ----  -----------  --------"
    echo "1       2048  Excellent    Fast"
    echo "2       3072  Excellent    Good"
    echo "3       4096  Very good    Good"
    echo "4       8192  Good         Slow"
    echo ""
    read -r -p "Which bit length shall be used? [1-4]: " BIT_LENGTH
    echo
    BIT_LENGTH_LOWER=$(echo "${BIT_LENGTH}" | tr '[:upper:]' '[:lower:]')
    if [[ "${BIT_LENGTH_LOWER}" =~ ^(2048|3072|4096|8192|1|2|3|4)$ ]]; then
      case "${BIT_LENGTH_LOWER}" in
        1) BIT_LENGTH="2048";;
        2) BIT_LENGTH="3072";;
        3) BIT_LENGTH="4096";;
        4) BIT_LENGTH="8192";;
        *) BIT_LENGTH="${BIT_LENGTH_LOWER}";;
      esac
      break
    else
      echo "Invalid bit length selected. Please try again."
    fi
  done

  openssl genrsa -out "${FILE_KEY}" "${BIT_LENGTH}"
  echo "File ${FILE_KEY} created!"

  openssl req -new -sha256 -config "${FILE_CNF}" -key "${FILE_KEY}" -out "${FILE_CSR}"
  echo "File ${FILE_CSR} created!"
fi

declare OPENSSL_CONF
export OPENSSL_CONF="${INTERMED_CNF_FILE}"
openssl rand -hex 16 > "${INTERMED_SERIAL_FILE}"
openssl ca -config "${INTERMED_CNF_FILE}" -in "${FILE_CSR}" -out "${FILE_CRT}" -passin "file:${FILE_INTERMED_PASSWD}"
openssl x509 -text -noout -in "${FILE_CRT}"
unset OPENSSL_CONF

cp "${CA_BUNDLE_FILE}" "${FILE_CA_CRT}"
openssl verify -verbose -CAfile "${FILE_CA_CRT}" "${FILE_CRT}"
openssl x509 -text -noout -in "${FILE_CRT}"

declare CA_ISSUED_CRT_DIR
CA_ISSUED_CRT_DIR="${CA_DIR}/issued/$(date +%Y%m%d)"
mkdir -p "${CA_ISSUED_CRT_DIR}"
mv "${WORKSPACE}" "${CA_ISSUED_CRT_DIR}/."

echo "Finished issuing certificate."
exit 0
