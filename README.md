# etcd Security Guide

A guide for deploying etcd clusters securely using TLS. 

etcd's default options, and many tutorials, don't use TLS or any form of authentication. As a result [many insecure clusters find their way into the wild][etcd-security-blog-post].

This document provides examples of how to provision TLS assets for an etcd cluster, and acts as a reference for which flags to enable to correctly secure client and peer traffic. At some point this content will be contributed to the [upstream etcd security guide][etcd-security].

This document requires the [latest release of etcd][etcd-releases], [CloudFlare's cfssl][cfssl-install], and [jq][jq-install] to run the examples.

## Running an etcd cluster using TLS

etcd instances require 2 sets of TLS certificates: one cert to serve client requests and a second for the peer endpoint used for communication between members. The peer cert doubles as a serving cert and client cert for traffic between the peers.

For this demo add the following entries to `/etc/hosts`:

```
127.0.0.1   etcd-1.local etcd-2.local etcd-3.local
```

The [`gen-certs.sh`](./scripts/gen-certs.sh) script uses `cfssl` to generate the initial TLS assets for a set of DNS names.

```
$ HOSTS="etcd-1.local,etcd-2.local,etcd-3.local" ./scripts/gen-certs.sh
$ tree tls/
tls/
├── assets
│   ├── admin-client.crt
│   ├── admin-client.key
│   ├── admin-client.txt
│   ├── ca.crt
│   ├── ca.key
│   ├── ca.txt
│   ├── member-1-peer.crt
│   ├── member-1-peer.key
│   ├── member-1-peer.txt
│   ├── member-1-server.crt
│   ├── member-1-server.key
│   ├── member-1-server.txt
│   ├── member-2-peer.crt
│   ├── member-2-peer.key
│   ├── member-2-peer.txt
│   ├── member-2-server.crt
│   ├── member-2-server.key
│   ├── member-2-server.txt
│   ├── member-3-peer.crt
│   ├── member-3-peer.key
│   ├── member-3-peer.txt
│   ├── member-3-server.crt
│   ├── member-3-server.key
│   └── member-3-server.txt
└── profiles
    ├── ca-config.json
    ├── ca-csr.json
    ├── client-csr.json
    ├── peer-csr.json
    └── server-csr.json

2 directories, 29 files
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
export ETCDCTL_CACERT=$PWD/tls/assets/ca.crt
export ETCDCTL_CERT=$PWD/tls/assets/admin-client.crt
export ETCDCTL_KEY=$PWD/tls/assets/admin-client.key
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
[jq-install]: https://stedolan.github.io/jq/
