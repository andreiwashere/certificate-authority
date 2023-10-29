# Certificate Authority
Be your own certificate authority for development and intranet purposes only.

## Installation

```sh
curl -s https://raw.githubusercontent.com/andreiwashere/certificate-authority/main/create_root_ca.sh > create_root_ca.sh
curl -s https://raw.githubusercontent.com/andreiwashere/certificate-authority/main/new_ca_signed_cert.sh > new_ca_signed_cert.sh
curl -s https://raw.githubusercontent.com/andreiwashere/certificate-authority/main/new_selfsigned_cert.sh > new_selfsigned_cert.sh
```

## Usage

```sh
chmod +x create_root_ca.sh
./create_root_ca.sh

chmod +x new_ca_signed_cert.sh
./new_ca_signed_cert.sh

chmod +x new_selfsigned_cert.sh
./new_selfsigned_cert.sh
```

### Helpful Tips

- Pick an easy to remember path like `/opt/ca` to store your CA.
- Place only 1 CA per host, otherwise name your directories like: `/opt/ca/mydomain.com` and `/opt/ca/anotherdomain.com`
- When issuing CA signed certificates, pass the CA directory as the 1st argument as `./new_ca_signed_cert.sh /opt/ca` or `./new_ca_signed_cert.sh /opt/ca/anotherdomain.com`
- Ensure that if you are issuing a signed certificate against your Root CA that it complies with your name constraints when initially configured. To check them, run:
  ```bash
  CA_DIR=/opt/ca
  ROOT_CRT_FILE=$(find "${CA_DIR}/root-ca" -maxdepth 1 -type f -name "*.root-ca.cert.pem")
  openssl x509 -in "$ROOT_CRT_FILE" -text -noout | grep "DNS:" | sed 's/DNS://g' | tr -d ' '
  ```
  You will be required to use subdomains belonging to any of the constrained names depending on how the Root CA was issued.

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

This assumes that you're using the `/opt/ca` directory for the `BASE_DIR` variable and your `ROOT_DOMAIN` is `example.com`:

```log
example.com/
├── certificates
│   ├── example.com.ca-bundle.crt
│   ├── Intermediate_Certificate_Authority.example.com.crt
│   └── Root_Certificate_Authority.example.com.crt
├── intermed-ca
│   ├── certreqs
│   ├── certs
│   ├── crl
│   │   ├── example.com.intermed-ca.crl
│   │   ├── example.com.intermed-ca.crlnum
│   │   └── example.com.intermed-ca.crlnum.old
│   ├── example.com.intermed-ca.cert.pem
│   ├── example.com.intermed-ca.cnf
│   ├── example.com.intermed-ca.index
│   ├── example.com.intermed-ca.index.attr
│   ├── example.com.intermed-ca.index.attr.old
│   ├── example.com.intermed-ca.index.old
│   ├── example.com.intermed-ca.req.pem
│   ├── example.com.intermed-ca.serial
│   ├── example.com.intermed-ca.serial.old
│   ├── newcerts
│   │   ├── 2F5B9C2A1464F78BAD1E3CBBF69704B9.pem
│   │   ├── BAF282D5DF1F2C64729D7186FD5E1D45.pem
│   │   ├── D6693DE57B77A0FDC71002195C7E3312.pem
│   │   └── EBF37D4506457A1003DF6E3EE6969DA4.pem
│   └── private
│       └── example.com.intermed-ca.key.pem
├── issued
│   └── 20231029
│       └── redis
│           ├── redis.ca-bundle.crt
│           ├── redis.cnf
│           ├── redis.crt
│           ├── redis.csr
│           └── redis.key
├── passwd
├── root-ca
│   ├── certreqs
│   │   └── example.com.intermed-ca.req.pem
│   ├── certs
│   │   └── intermed-ca.example.com.pem
│   ├── crl
│   │   ├── example.com.root-ca.crl
│   │   ├── example.com.root-ca.crlnum
│   │   └── example.com.root-ca.crlnum.old
│   ├── example.com.root-ca.cert.pem
│   ├── example.com.root-ca.cnf
│   ├── example.com.root-ca.index
│   ├── example.com.root-ca.index.attr
│   ├── example.com.root-ca.index.old
│   ├── example.com.root-ca.serial
│   ├── newcerts
│   │   └── 5EB54FF6113CD127626C8E56C8C779AACB560B73.pem
│   └── private
│       └── example.com.root-ca.key.pem
└── tmp

18 directories, 38 files
```

## TODO

- [X] Write `create_root_ca.sh`
- [X] Test `create_root_ca.sh`
- [X] Write `new_san_crt.sh`
- [X] Test `new_san_crt.sh`
- [X] Write `new_tls_crt.sh`
- [X] Test `new_tls_crt.sh`
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
