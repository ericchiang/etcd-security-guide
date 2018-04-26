#!/bin/bash -e

rm -rf tls
mkdir tls
mkdir tls/profiles
mkdir tls/assets

HOSTS=${HOSTS:-"etcd-1.local,etcd-2.local,etcd-3.local"}

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
}' > tls/profiles/ca-config.json

echo '{"CN":"etcd-ca","key":{"algo":"ecdsa","size":256}}' > tls/profiles/ca-csr.json
echo '{"CN":"root","key":{"algo":"ecdsa","size":256}}' > tls/profiles/client-csr.json
echo '{"CN":"etcd-member","key":{"algo":"ecdsa","size":256}}' > tls/profiles/peer-csr.json
echo '{"CN":"etcd-server","key":{"algo":"ecdsa","size":256}}' > tls/profiles/server-csr.json

cfssl gencert -initca tls/profiles/ca-csr.json > tls/assets/ca.json
unpack tls/assets/ca.json

cfssl gencert -ca=tls/assets/ca.crt -ca-key=tls/assets/ca.key \
    -config=tls/profiles/ca-config.json -profile=client \
    tls/profiles/client-csr.json > tls/assets/admin-client.json
unpack tls/assets/admin-client.json

IFS=','
I=1
for HOST in $( echo "$HOSTS" ); do
    cfssl gencert -ca=tls/assets/ca.crt -ca-key=tls/assets/ca.key \
        -config=tls/profiles/ca-config.json -profile=peer -hostname="$HOST" \
        tls/profiles/peer-csr.json > tls/assets/member-$I-peer.json

    cfssl gencert -ca=tls/assets/ca.crt -ca-key=tls/assets/ca.key \
        -config=tls/profiles/ca-config.json -profile=server -hostname="$HOST" \
        tls/profiles/server-csr.json > tls/assets/member-$I-server.json

    unpack tls/assets/member-$I-peer.json
    unpack tls/assets/member-$I-server.json

    I=$((I+1))
done

rm tls/assets/*.json
for CERT in tls/assets/*.crt; do
    openssl x509 -in $CERT -noout -text > "${CERT%.crt}.txt"
done
