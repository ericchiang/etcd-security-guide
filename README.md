# etcd Security Guide

A guide for deploying etcd clusters securely using TLS. 

etcd's default options, and many tutorials, don't use TLS or any form of authentication. As a result [many insecure clusters find their way into the wild][etcd-security-blog-post].

This document provides examples of how to provision TLS assets for an etcd cluster, and acts as a reference for which flags to enable to correctly secure client and peer traffic. At some point this content will be contributed to the [upstream etcd security guide][etcd-security].

This document requires the [latest release of etcd][etcd-releases] and CloudFlare's [cfssl and cfssljson][cfssl-install] tools to run the examples.

## Running an etcd cluster using TLS

etcd instances require 2 sets of TLS certificates: one cert to serve client requests and a second for the peer endpoint used for communication between members. The peer cert doubles as a serving cert and client cert for traffic between the peers.

For this demo add the following entries to `/etc/hosts`:

```
127.0.0.1   etcd-1.local etcd-2.local etcd-3.local
```

First, initialize the `cfssl` profiles and config files. These control the common name of the generate certificates, the allowed usages, and expiry:

```bash
mkdir -p tls/profiles
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
}' > tls/profiles/config.json
echo '{"CN":"etcd-ca","key":{"algo":"ecdsa","size":256}}' > tls/profiles/ca.json
echo '{"CN":"root","key":{"algo":"ecdsa","size":256}}' > tls/profiles/client.json
echo '{"CN":"etcd-member","key":{"algo":"ecdsa","size":256}}' > tls/profiles/peer.json
echo '{"CN":"etcd-server","key":{"algo":"ecdsa","size":256}}' > tls/profiles/server.json
```

Next, generate a certifiate authority, a client cert, and serving and peer certs for each member:

```bash
mkdir -p tls/assets

cfssl gencert -initca tls/profiles/ca.json | cfssljson -bare tls/assets/ca

# Generate a client cert
cfssl gencert -ca=tls/assets/ca.pem -ca-key=tls/assets/ca-key.pem \
    -config=tls/profiles/config.json -profile=client \
    tls/profiles/client.json | cfssljson -bare tls/assets/client

# Generate a serving and peer certs for each etcd member
cfssl gencert -ca=tls/assets/ca.pem -ca-key=tls/assets/ca-key.pem \
    -config=tls/profiles/config.json -profile=peer -hostname="etcd-1.local" \
    tls/profiles/peer.json | cfssljson -bare tls/assets/member-1-peer
cfssl gencert -ca=tls/assets/ca.pem -ca-key=tls/assets/ca-key.pem \
    -config=tls/profiles/config.json -profile=server -hostname="etcd-1.local" \
    tls/profiles/server.json | cfssljson -bare tls/assets/member-1-server

cfssl gencert -ca=tls/assets/ca.pem -ca-key=tls/assets/ca-key.pem \
    -config=tls/profiles/config.json -profile=peer -hostname="etcd-2.local" \
    tls/profiles/peer.json | cfssljson -bare tls/assets/member-2-peer
cfssl gencert -ca=tls/assets/ca.pem -ca-key=tls/assets/ca-key.pem \
    -config=tls/profiles/config.json -profile=server -hostname="etcd-2.local" \
    tls/profiles/server.json | cfssljson -bare tls/assets/member-2-server

cfssl gencert -ca=tls/assets/ca.pem -ca-key=tls/assets/ca-key.pem \
    -config=tls/profiles/config.json -profile=peer -hostname="etcd-3.local" \
    tls/profiles/peer.json | cfssljson -bare tls/assets/member-3-peer
cfssl gencert -ca=tls/assets/ca.pem -ca-key=tls/assets/ca-key.pem \
    -config=tls/profiles/config.json -profile=server -hostname="etcd-3.local" \
    tls/profiles/server.json | cfssljson -bare tls/assets/member-3-server

# Remove generated CSRs
rm tls/assets/*.csr
```

These commands will create the following directory structure:

```terminal
$ tree tls/
tls/
├── assets
│   ├── ca-key.pem
│   ├── ca.pem
│   ├── member-1-peer-key.pem
│   ├── member-1-peer.pem
│   ├── member-1-server-key.pem
│   ├── member-1-server.pem
│   ├── member-2-peer-key.pem
│   ├── member-2-peer.pem
│   ├── member-2-server-key.pem
│   ├── member-2-server.pem
│   ├── member-3-peer-key.pem
│   ├── member-3-peer.pem
│   ├── member-3-server-key.pem
│   └── member-3-server.pem
└── profiles
    ├── ca.json
    ├── client.json
    ├── config.json
    ├── peer.json
    └── server.json

2 directories, 19 files
```

The [`run-cluster.sh`](./scripts/run-cluster.sh) script runs a 3 member etcd cluster locally. It configures each to use the generated TLS assets and enables the correct set of flags to enforce authentication:

```
$ ./scripts/run-cluster.sh
etcd 1 running: PID 25622
etcd 2 running: PID 25623
etcd 3 running: PID 25624
```

Members write their logs to the `logs/` directory. Use `tail` to ensure the cluster came up correctly and formed quorum.

```
$ tail -f logs/*                  
```

Configure `etcdctl` with the admin client certificate:

```
export ETCDCTL_API=3
export ETCDCTL_ENDPOINTS='https://etcd-1.local:12379,https://etcd-2.local:22379,https://etcd-3.local:32379'
export ETCDCTL_CACERT=$PWD/tls/assets/ca.pem
export ETCDCTL_CERT=$PWD/tls/assets/client.pem
export ETCDCTL_KEY=$PWD/tls/assets/client-key.pem
```

If the scripts work `etcdctl` should be able to interact with the cluster:

```
$ etcdctl member list                                                
1dbd05ce059524ef, started, infra3, https://etcd-3.local:32380, https://etcd-3.local:32379                
690c4888e9365d4f, started, infra1, https://etcd-1.local:12380, https://etcd-1.local:12379                
7bf52a4b91dbdccb, started, infra2, https://etcd-2.local:22380, https://etcd-2.local:22379 
```

[cfssl-install]: https://github.com/cloudflare/cfssl#installation
[etcd-auth]: https://coreos.com/etcd/docs/latest/op-guide/authentication.html
[etcd-releases]: https://github.com/coreos/etcd/releases
[etcd-security]: https://coreos.com/etcd/docs/latest/op-guide/security.html
[etcd-security-blog-post]: https://elweb.co/the-security-footgun-in-etcd/
