# Demo of Certificate Authority

This is a demonstration of running the Certificate Authority commands on Rocky 9 linux.

```bash
cd /opt
sudo mkdir ca
sudo chown "$(whoami):$(whoami)" ca
cd ca
curl -s https://raw.githubusercontent.com/andreiwashere/certificate-authority/main/create_root_ca.sh > create-ca.sh
curl -s https://raw.githubusercontent.com/andreiwashere/certificate-authority/main/new_ca_signed_cert.sh > issue_signed_ca_cert.sh
chmod +x create-ca.sh
chmod +x issue_signed_ca_cert.sh
./create-ca.sh
tree -L 7 hogwarts.com/
stat hogwarts.com/passwd/.root-ca.hogwarts.com.passwd
cat hogwarts.com/root-ca/hogwarts.com.root-ca.cnf
./issue_signed_ca_cert.sh hogwarts.com
tree -L 7 hogwarts.com/
cat hogwarts.com/issued/20231029/redis/redis.cnf
rm -rf hogwarts.com
```

The detailed output of this demo can be seen below. Keep in mind, this Root CA was deleted immediately after being generated, so please don't get any slick ideas their sailor moon. 

## The Demo

- [See What We Have](#see-what-we-have)
- [Create Root Certificate Authority](#create-root-certificate-authority)
- [Inspect Root Certificate Authority](#inspect-root-certificate-authority)
- [Issue SAN TLS Certificate For `redis` with Intermediate CA](#issue-san-tls-certificate-for-redis-with-intermediate-ca)
- [Inspect SAN TLS Certificate](#inspect-san-tls-certificate)
- [Certificate Authority Encryption Keys](#certificate-authority-encryption-keys)
- [Certificate Authority Configurations](#certificate-authority-configurations)
- [SAN TLS Certificate Signing Request (CSR) Configuration](#san-tls-certificate-signing-request-csr-configuration)
- [Clean Up, Clean Up, Everybody Everywhere, Clean Up, Clean Up, Everybody Do Your Share](#clean-up-clean-up-everybody-everywhere-clean-up-clean-up-everybody-do-your-share)

### See What We Have

```log
[headmaster@ca ca]$ pwd
/opt/ca
```

```log
[headmaster@ca ca]$ ll
total 56
-rwxr-xr-x. 1 headmaster headmaster 31814 Oct 29 12:14 create-ca.sh
-rwxr-xr-x. 1 headmaster headmaster 18654 Oct 29 02:55 issue_signed_ca_cert.sh
-rwxr-xr-x. 1 headmaster headmaster  1464 Oct 28 17:40 selfsigned-cert.sh
```

[☝️ Top](#the-demo)

### Create Root Certificate Authority

```log
[headmaster@ca ca]$ ./create-ca.sh 
Where do you want to save the Root CA? (default: /opt/ca): /opt/ca/hogwarts.com

Root Certificate Authority Name: Hogwarts

City where Hogwarts is located (eg. Miami): Hogsmeade

State Code (eg FL) where Hogwarts is located: GB

Root Domain Name (eg. domain.com): hogwarts.com

Created directories: 
1. /opt/ca/hogwarts.com/root-ca
2. /opt/ca/hogwarts.com/intermed-ca
3. /opt/ca/hogwarts.com/tmp
4. /opt/ca/hogwarts.com/certificates
5. /opt/ca/hogwarts.com/passwd
Defining the script's environment...

[Root Certificate Authority]
Directory /opt/ca/hogwarts.com/root-ca/certreqs created!
Directory /opt/ca/hogwarts.com/root-ca/certs created!
Directory /opt/ca/hogwarts.com/root-ca/crl created!
Directory /opt/ca/hogwarts.com/root-ca/newcerts created!
Directory /opt/ca/hogwarts.com/root-ca/private created!

List of Permitted Domains for Root CA: hogwarts.com

Choose an option:
1. Add New DNS Entry
2. Remove DNS Entry
3. Clear All DNS Entries
4. Done adding DNS Entries [exit loop and continue]
Choose an option [1|2|3|4]: 1

Enter New DNS Entry: hogsmeade.com

List of Permitted Domains for Root CA: hogwarts.com hogsmeade.com

Choose an option:
1. Add New DNS Entry
2. Remove DNS Entry
3. Clear All DNS Entries
4. Done adding DNS Entries [exit loop and continue]
Choose an option [1|2|3|4]: 1

Enter New DNS Entry: gringotts.com

List of Permitted Domains for Root CA: hogwarts.com hogsmeade.com gringotts.com

Choose an option:
1. Add New DNS Entry
2. Remove DNS Entry
3. Clear All DNS Entries
4. Done adding DNS Entries [exit loop and continue]
Choose an option [1|2|3|4]: 1

Enter New DNS Entry: diagonalley.com

List of Permitted Domains for Root CA: hogwarts.com hogsmeade.com gringotts.com diagonalley.com

Choose an option:
1. Add New DNS Entry
2. Remove DNS Entry
3. Clear All DNS Entries
4. Done adding DNS Entries [exit loop and continue]
Choose an option [1|2|3|4]: 1

Enter New DNS Entry: azkaban.com

List of Permitted Domains for Root CA: hogwarts.com hogsmeade.com gringotts.com diagonalley.com azkaban.com

Choose an option:
1. Add New DNS Entry
2. Remove DNS Entry
3. Clear All DNS Entries
4. Done adding DNS Entries [exit loop and continue]
Choose an option [1|2|3|4]: 1

Enter New DNS Entry: ministryofmagic.com

List of Permitted Domains for Root CA: hogwarts.com hogsmeade.com gringotts.com diagonalley.com azkaban.com ministryofmagic.com

Choose an option:
1. Add New DNS Entry
2. Remove DNS Entry
3. Clear All DNS Entries
4. Done adding DNS Entries [exit loop and continue]
Choose an option [1|2|3|4]: 1

Enter New DNS Entry: wizengamot.com

List of Permitted Domains for Root CA: hogwarts.com hogsmeade.com gringotts.com diagonalley.com azkaban.com ministryofmagic.com wizengamot.com

Choose an option:
1. Add New DNS Entry
2. Remove DNS Entry
3. Clear All DNS Entries
4. Done adding DNS Entries [exit loop and continue]
Choose an option [1|2|3|4]: 4

DNS entries for [name_constraints]: hogwarts.com hogsmeade.com gringotts.com diagonalley.com azkaban.com ministryofmagic.com wizengamot.com

Does this look good? [y|n*]: y

Preparing to issue a new Certificate Authority for Hogwarts with the domains:
- hogwarts.com
- hogsmeade.com
- gringotts.com
- diagonalley.com
- azkaban.com
- ministryofmagic.com
- wizengamot.com

File /opt/ca/hogwarts.com/root-ca/private/.rnd created!
File /opt/ca/hogwarts.com/root-ca/hogwarts.com.root-ca.cnf created!

[Intermediate Certificate Authority]
Directory /opt/ca/hogwarts.com/intermed-ca/certreqs created!
Directory /opt/ca/hogwarts.com/intermed-ca/certs created!
Directory /opt/ca/hogwarts.com/intermed-ca/crl created!
Directory /opt/ca/hogwarts.com/intermed-ca/newcerts created!
Directory /opt/ca/hogwarts.com/intermed-ca/private created!
File /opt/ca/hogwarts.com/intermed-ca/private/.rnd created!

File /opt/ca/hogwarts.com/intermed-ca/hogwarts.com.intermed-ca.cnf created!

[Root Certificate Authority]
File /opt/ca/hogwarts.com/root-ca/hogwarts.com.root-ca.index created!
File /opt/ca/hogwarts.com/root-ca/crl/hogwarts.com.root-ca.crlnum created!

Which encryption algorithm will Hogwarts for hogwarts.com use? [rsa|ecc]: ecc

File /opt/ca/hogwarts.com/passwd/.root-ca.hogwarts.com.passwd created!
File /opt/ca/hogwarts.com/passwd/.root-ca.hogwarts.com.passwd secured!

File /opt/ca/hogwarts.com/passwd/.intermed-ca.hogwarts.com.passwd created!
File /opt/ca/hogwarts.com/passwd/.intermed-ca.hogwarts.com.passwd secured!

File /opt/ca/hogwarts.com/root-ca/hogwarts.com.root-ca.serial created!
Which Elliptic Curve (EC) shall be used for hogwarts.com Root Certificate Authority? 

Choice  Curve           Field Size  Security   Performance
------  -----           ----------  --------   -----------
1       prime256v1      256 bits    Good       Good
2       secp384r1       384 bits    Very good  Good
3       brainpoolP512r1 512 bits    Excellent  Slow
4       nistp521        521 bits    Excellent  Slow
5       edwards25519    255 bits    Excellent  Fast

Which curve shall be used for hogwarts.com Root Certificate Authority? [1-5] 5

File /opt/ca/hogwarts.com/passwd/.root-ca.ecc-curve created!
File /opt/ca/hogwarts.com/root-ca/private/hogwarts.com.root-ca.key.pem created!
File /opt/ca/hogwarts.com/root-ca/hogwarts.com.root-ca.cert.pem created!
File /opt/ca/hogwarts.com/root-ca/private/hogwarts.com.root-ca.key.pem secured!
Certificate:
    Data:
        Serial Number:
            34:26:da:8a:b2:83:ab:d2:59:d7:d3:d4:fa:f2:d5:da:f8:c1:4e:b7
        Signature Algorithm: ED25519
        Issuer:
            organizationName          = Hogwarts
            commonName                = hogwarts.com
            emailAddress              = certmaster@hogwarts.com
        Validity
            Not Before: Oct 29 12:22:05 2023 GMT
            Not After : Dec 31 12:22:05 2040 GMT
        Subject:
            organizationName          = Hogwarts
            commonName                = hogwarts.com
            emailAddress              = certmaster@hogwarts.com
        X509v3 extensions:
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Key Usage: critical
                Digital Signature, Certificate Sign, CRL Sign
            X509v3 Name Constraints: critical
                Permitted:
                  DNS:hogwarts.com
                  DNS:hogsmeade.com
                  DNS:gringotts.com
                  DNS:diagonalley.com
                  DNS:azkaban.com
                  DNS:ministryofmagic.com
                  DNS:wizengamot.com
                  DNS:lan
                  email:hogwarts.com
                  email:hogsmeade.com
                  email:gringotts.com
                  email:diagonalley.com
                  email:azkaban.com
                  email:ministryofmagic.com
                  email:wizengamot.com
                  email:lan
            X509v3 Subject Key Identifier: 
                6A:8A:DE:87:DC:52:3D:1C:86:9E:D8:3F:8B:75:92:F4:EE:8E:F0:7C
            X509v3 Subject Alternative Name: 
                URI:http://ca.hogwarts.com, email:certmaster@hogwarts.com
            X509v3 Authority Key Identifier: 
                6A:8A:DE:87:DC:52:3D:1C:86:9E:D8:3F:8B:75:92:F4:EE:8E:F0:7C
            X509v3 Issuer Alternative Name: 
                URI:http://ca.hogwarts.com, email:certmaster@hogwarts.com
            Authority Information Access: 
                CA Issuers - URI:http://ca.hogwarts.com/certs/Root_CA.crt
            X509v3 CRL Distribution Points: 
                Full Name:
                  URI:http://ca.hogwarts.com/crl/Root_CA.crl
Using configuration from /opt/ca/hogwarts.com/root-ca/hogwarts.com.root-ca.cnf
File /opt/ca/hogwarts.com/certificates/Root_Certificate_Authority.hogwarts.com.crt created!

[Intermediate Certificate Authority]
File /opt/ca/hogwarts.com/intermed-ca/hogwarts.com.intermed-ca.index created!
File /opt/ca/hogwarts.com/intermed-ca/crl/hogwarts.com.intermed-ca.crlnum created!
File /opt/ca/hogwarts.com/intermed-ca/hogwarts.com.intermed-ca.serial created!
File /opt/ca/hogwarts.com/intermed-ca/private/hogwarts.com.intermed-ca.key.pem created!
File /opt/ca/hogwarts.com/intermed-ca/hogwarts.com.intermed-ca.req.pem created!
File /opt/ca/hogwarts.com/intermed-ca/private/hogwarts.com.intermed-ca.key.pem secured!
Copied hogwarts.com.intermed-ca.req.pem into /opt/ca/hogwarts.com/root-ca/certreqs
Signing the intermediate certificate with the Root CA...
Using configuration from /opt/ca/hogwarts.com/root-ca/hogwarts.com.root-ca.cnf
Check that the request matches the signature
Signature ok
Certificate Details:
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number:
            68:76:77:b2:72:6d:f9:bb:76:ff:da:aa:dd:4e:76:ce:ef:78:bb:9d
        Issuer:
            organizationName          = Hogwarts
            commonName                = hogwarts.com
            emailAddress              = certmaster@hogwarts.com
        Validity
            Not Before: Oct 28 00:00:00 2023 GMT
            Not After : Nov 15 00:00:00 2040 GMT
        Subject:
            organizationName          = Hogwarts
            commonName                = Hogwarts Intermediate Certificate Authority
        X509v3 extensions:
            X509v3 Basic Constraints: critical
                CA:TRUE, pathlen:0
            X509v3 Key Usage: critical
                Digital Signature, Certificate Sign, CRL Sign
            X509v3 Subject Key Identifier: 
                97:7D:F8:22:C1:C3:F7:7F:55:5C:7F:3A:CC:03:E7:2F:C1:65:51:70
            X509v3 Subject Alternative Name: 
                URI:http://ca.hogwarts.com, email:certmaster@hogwarts.com
            X509v3 Authority Key Identifier: 
                6A:8A:DE:87:DC:52:3D:1C:86:9E:D8:3F:8B:75:92:F4:EE:8E:F0:7C
            X509v3 Issuer Alternative Name: 
                URI:http://ca.hogwarts.com, email:certmaster@hogwarts.com
            Authority Information Access: 
                CA Issuers - URI:http://ca.hogwarts.com/certs/Root_CA.crt
            X509v3 CRL Distribution Points: 
                Full Name:
                  URI:http://ca.hogwarts.com/crl/Root_CA.crl
Certificate is to be certified until Nov 15 00:00:00 2040 GMT (6226 days)
Sign the certificate? [y/n]:y


1 out of 1 certificate requests certified, commit? [y/n]y
Write out database with 1 new entries
Data Base Updated
File /opt/ca/hogwarts.com/root-ca/certs/intermed-ca.hogwarts.com.pem created!
Verifying the intermediate certificate...
Certificate:
    Data:
        Serial Number:
            68:76:77:b2:72:6d:f9:bb:76:ff:da:aa:dd:4e:76:ce:ef:78:bb:9d
        Signature Algorithm: ED25519
        Issuer:
            organizationName          = Hogwarts
            commonName                = hogwarts.com
            emailAddress              = certmaster@hogwarts.com
        Validity
            Not Before: Oct 28 00:00:00 2023 GMT
            Not After : Nov 15 00:00:00 2040 GMT
        Subject:
            organizationName          = Hogwarts
            commonName                = Hogwarts Intermediate Certificate Authority
        X509v3 extensions:
            X509v3 Basic Constraints: critical
                CA:TRUE, pathlen:0
            X509v3 Key Usage: critical
                Digital Signature, Certificate Sign, CRL Sign
            X509v3 Subject Key Identifier: 
                97:7D:F8:22:C1:C3:F7:7F:55:5C:7F:3A:CC:03:E7:2F:C1:65:51:70
            X509v3 Subject Alternative Name: 
                URI:http://ca.hogwarts.com, email:certmaster@hogwarts.com
            X509v3 Authority Key Identifier: 
                6A:8A:DE:87:DC:52:3D:1C:86:9E:D8:3F:8B:75:92:F4:EE:8E:F0:7C
            X509v3 Issuer Alternative Name: 
                URI:http://ca.hogwarts.com, email:certmaster@hogwarts.com
            Authority Information Access: 
                CA Issuers - URI:http://ca.hogwarts.com/certs/Root_CA.crt
            X509v3 CRL Distribution Points: 
                Full Name:
                  URI:http://ca.hogwarts.com/crl/Root_CA.crl
File /opt/ca/hogwarts.com/intermed-ca/hogwarts.com.intermed-ca.cert.pem created!
File /opt/ca/hogwarts.com/certificates/Intermediate_Certificate_Authority.hogwarts.com.crt created!
File /opt/ca/hogwarts.com/certificates/hogwarts.com.ca-bundle.crt created!
Attempting to verify the newly issued Intermediate Certificate against the Root Authority...
/opt/ca/hogwarts.com/intermed-ca/hogwarts.com.intermed-ca.cert.pem: OK
/opt/ca/hogwarts.com/certificates/hogwarts.com.ca-bundle.crt: OK
Verifed the intermediate certificate against the root certificate
Using configuration from /opt/ca/hogwarts.com/intermed-ca/hogwarts.com.intermed-ca.cnf
File /opt/ca/hogwarts.com/intermed-ca/crl/hogwarts.com.intermed-ca.crl created!
We recommend that you copy these into /etc/ssl/certs...

  sudo cp /opt/ca/hogwarts.com/root-ca/hogwarts.com.root-ca.cert.pem /etc/ssl/certs/hogwarts.com.root-ca.cert.pem
  sudo cp /opt/ca/hogwarts.com/intermed-ca/hogwarts.com.intermed-ca.cert.pem /etc/ssl/certs/hogwarts.com.intermed-ca.cert.pem
  sudo update-ca-certificates
```

[☝️ Top](#the-demo)

### Inspect Root Certificate Authority

```log
[headmaster@ca ca]$ tree -L 6 hogwarts.com/
hogwarts.com/
├── certificates
│   ├── hogwarts.com.ca-bundle.crt
│   ├── Intermediate_Certificate_Authority.hogwarts.com.crt
│   └── Root_Certificate_Authority.hogwarts.com.crt
├── intermed-ca
│   ├── certreqs
│   ├── certs
│   ├── crl
│   │   ├── hogwarts.com.intermed-ca.crl
│   │   ├── hogwarts.com.intermed-ca.crlnum
│   │   └── hogwarts.com.intermed-ca.crlnum.old
│   ├── hogwarts.com.intermed-ca.cert.pem
│   ├── hogwarts.com.intermed-ca.cnf
│   ├── hogwarts.com.intermed-ca.index
│   ├── hogwarts.com.intermed-ca.req.pem
│   ├── hogwarts.com.intermed-ca.serial
│   ├── newcerts
│   └── private
│       └── hogwarts.com.intermed-ca.key.pem
├── passwd
├── root-ca
│   ├── certreqs
│   │   └── hogwarts.com.intermed-ca.req.pem
│   ├── certs
│   │   └── intermed-ca.hogwarts.com.pem
│   ├── crl
│   │   ├── hogwarts.com.root-ca.crl
│   │   ├── hogwarts.com.root-ca.crlnum
│   │   └── hogwarts.com.root-ca.crlnum.old
│   ├── hogwarts.com.root-ca.cert.pem
│   ├── hogwarts.com.root-ca.cnf
│   ├── hogwarts.com.root-ca.index
│   ├── hogwarts.com.root-ca.index.attr
│   ├── hogwarts.com.root-ca.index.old
│   ├── hogwarts.com.root-ca.serial
│   ├── newcerts
│   │   └── 687677B2726DF9BB76FFDAAADD4E76CEEF78BB9D.pem
│   └── private
│       └── hogwarts.com.root-ca.key.pem
└── tmp

15 directories, 25 files
```

```log
[headmaster@ca ca]$ ll
total 56
-rwxr-xr-x. 1 headmaster headmaster 31814 Oct 29 12:14 create-ca.sh
drwxr-xr-x. 7 headmaster headmaster    85 Oct 29 12:18 hogwarts.com
-rwxr-xr-x. 1 headmaster headmaster 18654 Oct 29 02:55 issue_signed_ca_cert.sh
-rwxr-xr-x. 1 headmaster headmaster  1464 Oct 28 17:40 selfsigned-cert.sh
```

[☝️ Top](#the-demo)

### Issue SAN TLS Certificate For `redis` with Intermediate CA

```log
[headmaster@ca ca]$ ./issue_signed_ca_cert.sh hogwarts.com
CA_DIR = /opt/ca/hogwarts.com
Enter the label for this new certificate (eg: redis): redis

FILE_INTERMED_PASSWD = /opt/ca/hogwarts.com/passwd/.intermed-ca.hogwarts.com.passwd
List of DNS for certificate: 

Choose an option:
1. Add New DNS Entry
2. Remove DNS Entry
3. Clear All DNS Entries
4. Done adding DNS Entries [exit loop and continue]
Choose an option [1|2|3|4]: 1

Enter New DNS Entry: redis-01.hogwarts.com redis-02.hogwarts.com redis-03.hogwarts.com

List of DNS for certificate: redis-01.hogwarts.com redis-02.hogwarts.com redis-03.hogwarts.com

Choose an option:
1. Add New DNS Entry
2. Remove DNS Entry
3. Clear All DNS Entries
4. Done adding DNS Entries [exit loop and continue]
Choose an option [1|2|3|4]: 4

DNS entries for [name_constraints]: redis-01.hogwarts.com redis-02.hogwarts.com redis-03.hogwarts.com

Does this look good? [y|n*]: y

Preparing to issue a new signed certificate with the domains:
- redis-01.hogwarts.com
- redis-02.hogwarts.com
- redis-03.hogwarts.com

List of SAN IPs: 

Choose an option:
1. Add New IP Entry
2. Remove IP Entry
3. Clear All IP Entries
4. Done adding IP Entries [exit loop and continue]
Choose an option [1|2|3|4]: 1

Enter New IP Entries (separated by spaces or commas): 10.0.10.10 10.0.20.10 10.0.30.10
Added the following valid IPs:
10.0.10.10
10.0.20.10
10.0.30.10
List of SAN IPs: 10.0.10.10 10.0.20.10 10.0.30.10

Choose an option:
1. Add New IP Entry
2. Remove IP Entry
3. Clear All IP Entries
4. Done adding IP Entries [exit loop and continue]
Choose an option [1|2|3|4]: 4

IP entries for [name_constraints]: 10.0.10.10 10.0.20.10 10.0.30.10

Does this look good? [y|n*]: y

Preparing to issue a new signed certificate with the SAN IPs:
- 10.0.10.10
- 10.0.20.10
- 10.0.30.10

How many days do you want the certificate to be valid? 3333

Which encryption algorithm shall we use? [rsa|ecc]: ecc

Which Elliptic Curve (EC) shall we use? 

Choice  Curve           Field Size  Security   Performance
------  -----           ----------  --------   -----------
1       prime256v1      256 bits    Good       Good
2       secp384r1       384 bits    Very good  Good
3       brainpoolP512r1 512 bits    Excellent  Slow
4       nistp521        521 bits    Excellent  Slow
5       edwards25519    255 bits    Excellent  Fast

Which curve do you want to use? [1-5] 5

File /opt/ca/hogwarts.com/tmp/redis/redis.key created!
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country (2 Letter Code) []:GB
State (2 Letter Code) []:SC
Locality (eg City) []:Hogsmeade
Organization (eg Company Name) []:Hogwarts
Organizational Unit (eg Website) []:Redis
Email Address []:redis@hogwarts.com
Common Name []:*.hogwarts.com
File /opt/ca/hogwarts.com/tmp/redis/redis.csr created!
Using configuration from /opt/ca/hogwarts.com/intermed-ca/hogwarts.com.intermed-ca.cnf
Check that the request matches the signature
Signature ok
Certificate Details:
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number:
            99:9b:d2:3d:32:35:46:7b:65:bd:85:7c:f2:20:34:dd
        Issuer:
            organizationName          = Hogwarts
            commonName                = Hogwarts Intermediate Certificate Authority
        Validity
            Not Before: Oct 29 12:25:42 2023 GMT
            Not After : Dec 13 12:25:42 2032 GMT
        Subject:
            countryName               = GB
            stateOrProvinceName       = SC
            localityName              = Hogsmeade
            organizationName          = Hogwarts
            organizationalUnitName    = Redis
            commonName                = *.hogwarts.com
        X509v3 extensions:
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication, Code Signing, E-mail Protection
            X509v3 Basic Constraints: 
                CA:FALSE
            X509v3 Key Usage: 
                Digital Signature, Non Repudiation, Key Encipherment, Data Encipherment
            X509v3 Subject Alternative Name: 
                DNS:redis-01.hogwarts.com, DNS:redis-02.hogwarts.com, DNS:redis-03.hogwarts.com, IP Address:10.0.10.10, IP Address:10.0.20.10, IP Address:10.0.30.10
Certificate is to be certified until Dec 13 12:25:42 2032 GMT (3333 days)
Sign the certificate? [y/n]:y


1 out of 1 certificate requests certified, commit? [y/n]y
Write out database with 1 new entries
Data Base Updated
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            99:9b:d2:3d:32:35:46:7b:65:bd:85:7c:f2:20:34:dd
        Signature Algorithm: ED25519
        Issuer: O = Hogwarts, CN = Hogwarts Intermediate Certificate Authority
        Validity
            Not Before: Oct 29 12:25:42 2023 GMT
            Not After : Dec 13 12:25:42 2032 GMT
        Subject: C = GB, ST = SC, L = Hogsmeade, O = Hogwarts, OU = Redis, CN = *.hogwarts.com
        Subject Public Key Info:
            Public Key Algorithm: ED25519
                ED25519 Public-Key:
                pub:
                    97:32:b3:ff:79:24:8f:eb:f9:2e:2b:28:d0:ae:f1:
                    b5:70:16:b3:b3:59:bd:96:6c:15:ac:2b:04:13:0d:
                    cc:eb
        X509v3 extensions:
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication, Code Signing, E-mail Protection
            X509v3 Basic Constraints: 
                CA:FALSE
            X509v3 Key Usage: 
                Digital Signature, Non Repudiation, Key Encipherment, Data Encipherment
            X509v3 Subject Alternative Name: 
                DNS:redis-01.hogwarts.com, DNS:redis-02.hogwarts.com, DNS:redis-03.hogwarts.com, IP Address:10.0.10.10, IP Address:10.0.20.10, IP Address:10.0.30.10
            X509v3 Subject Key Identifier: 
                1B:74:F5:4C:B8:65:0F:68:8C:A6:77:EF:90:83:F0:93:3A:EB:27:31
            X509v3 Authority Key Identifier: 
                97:7D:F8:22:C1:C3:F7:7F:55:5C:7F:3A:CC:03:E7:2F:C1:65:51:70
    Signature Algorithm: ED25519
    Signature Value:
        68:64:78:3e:83:52:21:9e:c3:06:dc:0c:c9:f2:27:e1:48:02:
        6f:fe:6a:3d:99:4e:78:12:6a:6e:6b:41:87:a4:d2:68:c0:3a:
        c0:e1:4b:15:89:fa:98:dc:4d:7e:0d:c0:80:16:25:00:b0:ee:
        9b:84:f3:46:1d:52:78:4e:91:0e
/opt/ca/hogwarts.com/tmp/redis/redis.crt: OK
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            99:9b:d2:3d:32:35:46:7b:65:bd:85:7c:f2:20:34:dd
        Signature Algorithm: ED25519
        Issuer: O = Hogwarts, CN = Hogwarts Intermediate Certificate Authority
        Validity
            Not Before: Oct 29 12:25:42 2023 GMT
            Not After : Dec 13 12:25:42 2032 GMT
        Subject: C = GB, ST = SC, L = Hogsmeade, O = Hogwarts, OU = Redis, CN = *.hogwarts.com
        Subject Public Key Info:
            Public Key Algorithm: ED25519
                ED25519 Public-Key:
                pub:
                    97:32:b3:ff:79:24:8f:eb:f9:2e:2b:28:d0:ae:f1:
                    b5:70:16:b3:b3:59:bd:96:6c:15:ac:2b:04:13:0d:
                    cc:eb
        X509v3 extensions:
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication, Code Signing, E-mail Protection
            X509v3 Basic Constraints: 
                CA:FALSE
            X509v3 Key Usage: 
                Digital Signature, Non Repudiation, Key Encipherment, Data Encipherment
            X509v3 Subject Alternative Name: 
                DNS:redis-01.hogwarts.com, DNS:redis-02.hogwarts.com, DNS:redis-03.hogwarts.com, IP Address:10.0.10.10, IP Address:10.0.20.10, IP Address:10.0.30.10
            X509v3 Subject Key Identifier: 
                1B:74:F5:4C:B8:65:0F:68:8C:A6:77:EF:90:83:F0:93:3A:EB:27:31
            X509v3 Authority Key Identifier: 
                97:7D:F8:22:C1:C3:F7:7F:55:5C:7F:3A:CC:03:E7:2F:C1:65:51:70
    Signature Algorithm: ED25519
    Signature Value:
        68:64:78:3e:83:52:21:9e:c3:06:dc:0c:c9:f2:27:e1:48:02:
        6f:fe:6a:3d:99:4e:78:12:6a:6e:6b:41:87:a4:d2:68:c0:3a:
        c0:e1:4b:15:89:fa:98:dc:4d:7e:0d:c0:80:16:25:00:b0:ee:
        9b:84:f3:46:1d:52:78:4e:91:0e
Finished issuing certificate.
```

[☝️ Top](#the-demo)

### Inspect SAN TLS Certificate

```log
[headmaster@ca ca]$ tree -L 7 hogwarts.com/
hogwarts.com/
├── certificates
│   ├── hogwarts.com.ca-bundle.crt
│   ├── Intermediate_Certificate_Authority.hogwarts.com.crt
│   └── Root_Certificate_Authority.hogwarts.com.crt
├── intermed-ca
│   ├── certreqs
│   ├── certs
│   ├── crl
│   │   ├── hogwarts.com.intermed-ca.crl
│   │   ├── hogwarts.com.intermed-ca.crlnum
│   │   └── hogwarts.com.intermed-ca.crlnum.old
│   ├── hogwarts.com.intermed-ca.cert.pem
│   ├── hogwarts.com.intermed-ca.cnf
│   ├── hogwarts.com.intermed-ca.index
│   ├── hogwarts.com.intermed-ca.index.attr
│   ├── hogwarts.com.intermed-ca.index.old
│   ├── hogwarts.com.intermed-ca.req.pem
│   ├── hogwarts.com.intermed-ca.serial
│   ├── hogwarts.com.intermed-ca.serial.old
│   ├── newcerts
│   │   └── 999BD23D3235467B65BD857CF22034DD.pem
│   └── private
│       └── hogwarts.com.intermed-ca.key.pem
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
│   │   └── hogwarts.com.intermed-ca.req.pem
│   ├── certs
│   │   └── intermed-ca.hogwarts.com.pem
│   ├── crl
│   │   ├── hogwarts.com.root-ca.crl
│   │   ├── hogwarts.com.root-ca.crlnum
│   │   └── hogwarts.com.root-ca.crlnum.old
│   ├── hogwarts.com.root-ca.cert.pem
│   ├── hogwarts.com.root-ca.cnf
│   ├── hogwarts.com.root-ca.index
│   ├── hogwarts.com.root-ca.index.attr
│   ├── hogwarts.com.root-ca.index.old
│   ├── hogwarts.com.root-ca.serial
│   ├── newcerts
│   │   └── 687677B2726DF9BB76FFDAAADD4E76CEEF78BB9D.pem
│   └── private
│       └── hogwarts.com.root-ca.key.pem
└── tmp

18 directories, 34 files
```

[☝️ Top](#the-demo)

### Certificate Authority Encryption Keys

```log
[headmaster@ca ca]$ ls -la hogwarts.com/passwd/
total 12
drwxr-xr-x. 2 headmaster headmaster 108 Oct 29 12:22 .
drwxr-xr-x. 8 headmaster headmaster  99 Oct 29 12:25 ..
-r--------. 1 headmaster headmaster  73 Oct 29 12:22 .intermed-ca.hogwarts.com.passwd
-rw-r--r--. 1 headmaster headmaster  13 Oct 29 12:22 .root-ca.ecc-curve
-r--------. 1 headmaster headmaster  72 Oct 29 12:22 .root-ca.hogwarts.com.passwd
```

```log
[headmaster@ca ca]$ stat hogwarts.com/passwd/.root-ca.hogwarts.com.passwd 
  File: hogwarts.com/passwd/.root-ca.hogwarts.com.passwd
  Size: 72              Blocks: 8          IO Block: 4096   regular file
Device: fc01h/64513d    Inode: 50331791    Links: 1
Access: (0400/-r--------)  Uid: ( 1000/headmaster)   Gid: ( 1000/headmaster)
Context: unconfined_u:object_r:user_home_t:s0
Access: 2023-10-29 12:22:05.880877162 +0000
Modify: 2023-10-29 12:22:04.231823909 +0000
Change: 2023-10-29 12:22:04.233823973 +0000
 Birth: 2023-10-29 12:22:04.230823876 +0000
```

[☝️ Top](#the-demo)

### Certificate Authority Configurations

```log
[headmaster@ca ca]$ cat hogwarts.com/root-ca/hogwarts.com.root-ca.cnf 
RANDFILE                          = /opt/ca/hogwarts.com/root-ca/private/.rnd
[ ca ]
default_ca                        = root_ca

[ root_ca ]
dir                               = /opt/ca/hogwarts.com/root-ca
certs                             = $dir/certs
crl_dir                           = $dir/crl
new_certs_dir                     = $dir/newcerts
database                          = $dir/hogwarts.com.root-ca.index
serial                            = $dir/hogwarts.com.root-ca.serial
rand_serial                       = yes

certificate                       = $dir/hogwarts.com.root-ca.cert.pem
private_key                       = $dir/private/hogwarts.com.root-ca.key.pem

crlnumber                         = $dir/crl/hogwarts.com.root-ca.crlnum
crl                               = $dir/crl/hogwarts.com.root-ca.crl
crl_extensions                    = crl_ext
default_crl_days                  = 180

default_md                        = sha256

name_opt                          = multiline, align
cert_opt                          = no_pubkey
default_days                      = 3333
preserve                          = no
policy                            = policy_strict
copy_extensions                   = copy
email_in_dn                       = no
unique_subject                    = no

[policy_strict]
countryName                       = optional
stateOrProvinceName               = optional
localityName                      = optional
organizationName                  = optional
emailAddress                      = optional
organizationalUnitName            = optional
commonName                        = supplied

[ req ]
default_bits                      = 4096
default_keyfile                   = private/hogwarts.com.root-ca.key.pem
encrypt_key                       = yes
default_md                        = sha256
string_mask                       = utf8only
utf8                              = yes
prompt                            = no
req_extensions                    = root-ca_req_ext
distinguished_name                = distinguished_name
subjectAltName                    = @subject_alt_name

[ root-ca_req_ext ]
subjectKeyIdentifier              = hash
subjectAltName                    = @subject_alt_name

[ distinguished_name ]
organizationName                  = Hogwarts
commonName                        = hogwarts.com
emailAddress                      = certmaster@hogwarts.com


[ root-ca_ext ]
basicConstraints                  = critical, CA:true
keyUsage                          = critical, keyCertSign, cRLSign, digitalSignature
nameConstraints                   = critical, @name_constraints
subjectKeyIdentifier              = hash
subjectAltName                    = @subject_alt_name
authorityKeyIdentifier            = keyid:always
issuerAltName                     = issuer:copy
authorityInfoAccess               = @auth_info_access
crlDistributionPoints             = @crl_dist

[ intermed-ca_ext ]
basicConstraints                  = critical, CA:true, pathlen:0
keyUsage                          = critical, keyCertSign, cRLSign, digitalSignature
subjectKeyIdentifier              = hash
subjectAltName                    = @subject_alt_name
authorityKeyIdentifier            = keyid:always
issuerAltName                     = issuer:copy
authorityInfoAccess               = @auth_info_access
crlDistributionPoints             = @crl_dist

[ crl_ext ]
authorityKeyIdentifier            = keyid:always
issuerAltName                     = issuer:copy

[ subject_alt_name ]
URI                               = http://ca.hogwarts.com
email                             = certmaster@hogwarts.com

[ auth_info_access ]
caIssuers;URI                     = http://ca.hogwarts.com/certs/Root_CA.crt

[ crl_dist ]
URI.1                             = http://ca.hogwarts.com/crl/Root_CA.crl

[ name_constraints ]
permitted;DNS.1          = hogwarts.com
permitted;DNS.2          = hogsmeade.com
permitted;DNS.3          = gringotts.com
permitted;DNS.4          = diagonalley.com
permitted;DNS.5          = azkaban.com
permitted;DNS.6          = ministryofmagic.com
permitted;DNS.7          = wizengamot.com
permitted;DNS.8          = lan
permitted;email.1        = hogwarts.com
permitted;email.2        = hogsmeade.com
permitted;email.3        = gringotts.com
permitted;email.4        = diagonalley.com
permitted;email.5        = azkaban.com
permitted;email.6        = ministryofmagic.com
permitted;email.7        = wizengamot.com
permitted;email.8        = lan
```

[☝️ Top](#the-demo)

### SAN TLS Certificate Signing Request (CSR) Configuration

```log
[headmaster@ca ca]$ cat hogwarts.com/issued/20231029/redis/redis.cnf 
[req]
days                    = 3333
default_bits            = 4096
default_md              = sha256
default_keyfile         = /opt/ca/hogwarts.com/tmp/redis/redis.key
distinguished_name      = req_distinguished_name
x509_extensions         = v3_ca
req_extensions          = v3_req

[ req_distinguished_name ]
C                       = Country (2 Letter Code)
ST                      = State (2 Letter Code)
L                       = Locality (eg City)
O                       = Organization (eg Company Name)
OU                      = Organizational Unit (eg Website)
emailAddress            = Email Address
CN                      = Common Name

[ v3_ca ]
subjectAltName          = @alt_names
issuerAltName           = issuer:copy

[ v3_req ]
extendedKeyUsage        = serverAuth, clientAuth, codeSigning, emailProtection
basicConstraints        = CA:FALSE
keyUsage                = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName          = @alt_names

[ alt_names ]
DNS.1 = redis-01.hogwarts.com
DNS.2 = redis-02.hogwarts.com
DNS.3 = redis-03.hogwarts.com
IP.1 = 10.0.10.10
IP.2 = 10.0.20.10
IP.3 = 10.0.30.10
```

[☝️ Top](#the-demo)

## Clean Up, Clean Up, Everybody Everywhere, Clean Up, Clean Up, Everybody Do Your Share

```log
[headmaster@ca ca]$ ls -la
total 56
drwxr-xr-x. 3 headmaster headmaster   103 Oct 29 12:17 .
drwxr-xr-x. 5 root       root          50 Oct 29 12:14 ..
-rwxr-xr-x. 1 headmaster headmaster 31814 Oct 29 12:14 create-ca.sh
drwxr-xr-x. 8 headmaster headmaster    99 Oct 29 12:25 hogwarts.com
-rwxr-xr-x. 1 headmaster headmaster 18654 Oct 29 02:55 issue_signed_ca_cert.sh
-rwxr-xr-x. 1 headmaster headmaster  1464 Oct 28 17:40 selfsigned-cert.sh
```

```log
[headmaster@ca ca]$ rm -rf hogwarts.com
```

```log
[headmaster@ca ca]$ ls -la
total 56
drwxr-xr-x. 2 headmaster headmaster    83 Oct 29 12:29 .
drwxr-xr-x. 5 root       root          50 Oct 29 12:14 ..
-rwxr-xr-x. 1 headmaster headmaster 31814 Oct 29 12:14 create-ca.sh
-rwxr-xr-x. 1 headmaster headmaster 18654 Oct 29 02:55 issue_signed_ca_cert.sh
-rwxr-xr-x. 1 headmaster headmaster  1464 Oct 28 17:40 selfsigned-cert.sh
```

[☝️ Top](#the-demo)
