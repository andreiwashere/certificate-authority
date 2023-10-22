# Certificate Authority
Be your own certificate authority for development and intranet purposes only.

## Installation

```sh
URL="https://raw.githubusercontent.com/andreiwashere/certificate-authority/main/create_root_ca.sh"
wget --secure-protocol=auto --no-cache -O "${URL}" "create_root_ca.sh" < /dev/null > /dev/null 2>&1
```

## Usage

```sh
chmod +x create_root_ca.sh
./create_root_ca.sh
```

### Prompts

| Prompt | Default | Variable |
|--------|---------|----------|
| Where do you want to save the Root CA? (eg /opt/ca): | `/opt/ca` | `BASE_DIR` |
| Root Certificate Authority Name: | `<blank>` | `CA_NAME` |
| City where `${CA_NAME}` is located (eg. Concord):  | NONE | `CA_LOCALITY` |
| State Code (eg FL) where `${CA_NAME}` is located: | NONE | `CA_STATE` |
| Root Domain Name (eg. domain.com): | NONE | `ROOT_DOMAIN` | 
| Add DNS Entry: | NONE | `permitted_domain` |
| Add another? [y\|n]: | NONE | `choice` |
| Does this look good? [y\|n]: | NONE | `looks_good` |
| Which encryption algorithm will `${CA_NAME}` for `${ROOT_DOMAIN}` use? [rsa\|ecc]: | NONE | `ROOT_ALGORITHM` |
| Which curve shall be used for `${ROOT_DOMAIN}` Root Certificate Authority? [1-5] | NONE | `ROOT_ALGO_CURVE` | 
| Install certificate `$(basename "${ROOT_CRT_FILE}")` inside /etc/ssl/certs? (requires sudo): | NONE | `INSTALL_ROOT_CERT` | 
| Execute update-ca-certificates? (requires sudo): | NONE | `UPDATE_CA_CERTIFICATES` |

> `NONE` means the script does not have **any default value** for the associated prompt.


## Overview

The script operates interactively and will prompt you for various pieces of information, including:
  - The directory where you want to save the Root and Intermediate CAs
  - The name of your Certificate Authority
  - The city and state where your CA is located
  - The root domain name for your CA
  - The encryption algorithm (RSA or ECC) for your CA's private keys
  - The specific curve (if ECC is selected)

The script will then proceed to:
  - Create the necessary directory structure
  - Generate private keys and CSRs
  - Create the root and intermediate certificates
  - Optionally, install the certificates in the system's trust store
  - Optionally, update the system's CA certificates store

Please ensure you have the necessary dependencies installed (e.g., openssl) and adequate permissions (e.g., sudo access if you intend to install certificates system-wide).

WARNING: This script generates sensitive cryptographic materials. Handle them with extreme care and ensure they are adequately secured in production environments.

## Directory Structure 

This assumes that you're using the `/opt/ca` directory for the `BASE_DIR` variable and your `ROOT_DOMAIN` is `mydomain.com`:

```log
/opt/ca/root-ca
/opt/ca/root-ca/mydomain.com.root-ca.cnf
/opt/ca/root-ca/mydomain.com.root-ca.req.pem
/opt/ca/root-ca/mydomain.com.root-ca.cert.pem
/opt/ca/root-ca/mydomain.com.root-ca.serial
/opt/ca/root-ca/mydomain.com.root-ca.index
/opt/ca/root-ca/certreqs
/opt/ca/root-ca/crl
/opt/ca/root-ca/crl/mydomain.com.root-ca.crl
/opt/ca/root-ca/crl/mydomain.com.root-ca.crlnum
/opt/ca/root-ca/certs
/opt/ca/root-ca/newcerts
/opt/ca/root-ca/private
/opt/ca/root-ca/private/mydomain.com.root-ca.key.pem
/opt/ca/intermed-ca
/opt/ca/intermed-ca/mydomain.com.intermed-ca.cnf
/opt/ca/intermed-ca/mydomain.com.intermed-ca.req.pem
/opt/ca/intermed-ca/mydomain.com.intermed-ca.cert.pem
/opt/ca/intermed-ca/mydomain.com.intermed-ca.serial
/opt/ca/intermed-ca/mydomain.com.intermed-ca.index
/opt/ca/intermed-ca/certreqs
/opt/ca/intermed-ca/crl
/opt/ca/intermed-ca/crl/mydomain.com.intermed-ca.crl
/opt/ca/intermed-ca/crl/mydomain.com.intermed-ca.crlnum
/opt/ca/intermed-ca/certs
/opt/ca/intermed-ca/newcerts
/opt/ca/intermed-ca/private
/opt/ca/intermed-ca/private/mydomain.com.intermed-ca.key.pem
/opt/ca/tmp
/opt/ca/certificates
/etc/ssl/certs/ROOT-CA.mydomain.com.crt
/etc/ssl/certs/INTERMED-CA.mydomain.com.crt
```

## TODO

- [X] Write `create_root_ca.sh`
- [ ] Test `create_root_ca.sh`
- [ ] Write `new_san_crt.sh`
- [ ] Test `new_san_crt.sh`
- [ ] Write `new_tls_crt.sh`
- [ ] Test `new_tls_crt.sh`
- [ ] Write `reissue_crt.sh`
- [ ] Test `reissue_crt.sh`

# DISCLAIMER

The script, its documentation, and any associated information are provided on an "as is" basis, without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement. In no event shall the authors, copyright holders, or Apache 2.0 licensors be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the script or the use or other dealings in the script.

This script is licensed under the Apache License, Version 2.0 (the "License"); you may not use this script except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "as is" basis, without warranties or conditions of any kind, either express or implied. See the License for the specific language governing permissions and limitations under the License.

By using this script, you agree to the terms above, and you fully absolve the developer of any liability or claims that may arise from your use or misuse. Use at your own risk.

## Regulatory and Compliance Knowledge

Depending on the environment where this script is used, there might be regulatory requirements governing the use of cryptographic materials. This is especially true in sectors like finance, healthcare, and critical infrastructure.
