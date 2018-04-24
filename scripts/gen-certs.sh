#!/bin/bash -e

rm -rf tls
mkdir tls

HOSTS=${HOSTS:-"etcd-1.local etcd-2.local etcd-3.local"}

function unpack {
    DIR="$( dirname $1 )"
    NAME="$( basename $1 )"
    NAME="${NAME%.*}"

    jq -r '.cert' < $1 > $DIR/$NAME.crt
    jq -r '.key' < $1 > $DIR/$NAME.key
}

echo '{
  "signing": {
    "default": {
      "expiry": "43800h"
    },
    "profiles": {
      "server": {
        "expiry": "43800h",
        "usages": ["signing", "key encipherment", "server auth"]
      },
      "client": {
        "expiry": "43800h",
        "usages": ["signing", "key encipherment", "client auth"]
      },
      "peer": {
        "expiry": "43800h",
        "usages": ["signing", "key encipherment", "server auth", "client auth"]
      }
    }
  }
}' > tls/ca-config.json

echo '{"CN":"etcd-ca","key":{"algo":"ecdsa","size":256}}' > tls/etcd-ca-csr.json
echo '{"CN":"etcd-client","key":{"algo":"ecdsa","size":256}}' > tls/etcd-client-csr.json
echo '{"CN":"etcd-member","key":{"algo":"ecdsa","size":256}}' > tls/etcd-peer-csr.json
echo '{"CN":"etcd-server","key":{"algo":"ecdsa","size":256}}' > tls/etcd-server-csr.json

cfssl gencert -initca tls/etcd-ca-csr.json > tls/ca.json
unpack tls/ca.json

cfssl gencert -ca=tls/ca.crt -ca-key=tls/ca.key -config=tls/ca-config.json \
    -profile=client tls/etcd-client-csr.json > tls/etcd-client.json
unpack tls/etcd-client.json

I=1
for HOST in $( echo "$HOSTS" ); do
    cfssl gencert -ca=tls/ca.crt -ca-key=tls/ca.key -config=tls/ca-config.json \
        -profile=peer -hostname="$HOST" tls/etcd-peer-csr.json > tls/etcd-$I-peer.json
    cfssl gencert -ca=tls/ca.crt -ca-key=tls/ca.key -config=tls/ca-config.json \
        -profile=server -hostname="$HOST" tls/etcd-server-csr.json > tls/etcd-$I-server.json

    unpack tls/etcd-$I-peer.json
    unpack tls/etcd-$I-server.json

    I=$((I+1))
done

rm tls/*.json
for CERT in tls/*.crt; do
    openssl x509 -in $CERT -noout -text > "${CERT%.crt}.txt"
done
