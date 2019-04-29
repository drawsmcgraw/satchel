#!/bin/bash

DOMAIN='your.domain.name'
#-nodes \

openssl req -new \
-newkey rsa:2048 \
-keyout ${DOMAIN}.key \
-out ${DOMAIN}.csr \
-subj "/C=US/ST=CA/L=Beverly Hills/O=Syndicated Incorporated/OU=Team People/CN=*.${DOMAIN}" \
-reqexts SAN \
-extensions SAN \
-reqexts v3_req \
-extensions v3_req \
-config <(cat /etc/ssl/openssl.cnf <(printf "[v3_req]\n\
                                             extendedKeyUsage=serverAuth,clientAuth\n")); \


openssl rsa -in your.domain.name.key -out "${DOMAIN}".key.dec
openssl x509 -in "${DOMAIN}".csr -out "${DOMAIN}".crt -req -signkey "${DOMAIN}".key.dec -days 1001
