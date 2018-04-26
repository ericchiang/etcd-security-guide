#!/bin/bash -e

rm -rf data
rm -rf logs

mkdir data
mkdir logs

etcd \
    --name=infra1 \
    --data-dir=data/infra1.etcd \
    --listen-client-urls=https://127.0.0.1:12379 \
    --listen-peer-urls=https://127.0.0.1:12380 \
    --advertise-client-urls=https://etcd-1.local:12379 \
    --initial-advertise-peer-urls=https://etcd-1.local:12380 \
    --initial-cluster='infra1=https://etcd-1.local:12380,infra2=https://etcd-2.local:22380,infra3=https://etcd-3.local:32380' \
    --initial-cluster-state=new \
    --cert-file=tls/assets/member-1-server.pem \
    --key-file=tls/assets/member-1-server-key.pem \
    --peer-cert-file=tls/assets/member-1-peer.pem \
    --peer-key-file=tls/assets/member-1-peer-key.pem \
    --client-cert-auth=true \
    --trusted-ca-file=tls/assets/ca.pem \
    --peer-cert-allowed-cn=etcd-member \
    --peer-client-cert-auth=true \
    --peer-trusted-ca-file=tls/assets/ca.pem \
    --log-output=stderr > logs/etcd1.stdout 2> logs/etcd1.stderr &
pids[0]=$!
echo "etcd 1 running: PID ${pids[0]}"

etcd \
    --name infra2 \
    --data-dir=data/infra2.etcd \
    --listen-client-urls=https://127.0.0.1:22379 \
    --listen-peer-urls=https://127.0.0.1:22380 \
    --advertise-client-urls=https://etcd-2.local:22379 \
    --initial-advertise-peer-urls=https://etcd-2.local:22380 \
    --initial-cluster='infra1=https://etcd-1.local:12380,infra2=https://etcd-2.local:22380,infra3=https://etcd-3.local:32380' \
    --initial-cluster-state=new \
    --cert-file=tls/assets/member-2-server.pem \
    --key-file=tls/assets/member-2-server-key.pem \
    --peer-cert-file=tls/assets/member-2-peer.pem \
    --peer-key-file=tls/assets/member-2-peer-key.pem \
    --client-cert-auth=true \
    --trusted-ca-file=tls/assets/ca.pem \
    --peer-cert-allowed-cn=etcd-member \
    --peer-client-cert-auth=true \
    --peer-trusted-ca-file=tls/assets/ca.pem \
    --log-output stderr > logs/etcd2.stdout 2> logs/etcd2.stderr &
pids[1]=$!
echo "etcd 2 running: PID ${pids[1]}"

etcd \
    --name=infra3 \
    --data-dir=data/infra3.etcd \
    --listen-client-urls=https://127.0.0.1:32379 \
    --listen-peer-urls=https://127.0.0.1:32380 \
    --advertise-client-urls=https://etcd-3.local:32379 \
    --initial-advertise-peer-urls=https://etcd-3.local:32380 \
    --initial-cluster='infra1=https://etcd-1.local:12380,infra2=https://etcd-2.local:22380,infra3=https://etcd-3.local:32380' \
    --initial-cluster-state=new \
    --cert-file=tls/assets/member-3-server.pem \
    --key-file=tls/assets/member-3-server-key.pem \
    --peer-cert-file=tls/assets/member-3-peer.pem \
    --peer-key-file=tls/assets/member-3-peer-key.pem \
    --client-cert-auth=true \
    --trusted-ca-file=tls/assets/ca.pem \
    --peer-cert-allowed-cn=etcd-member \
    --peer-client-cert-auth=true \
    --peer-trusted-ca-file=tls/assets/ca.pem \
    --log-output stderr > logs/etcd3.stdout 2> logs/etcd3.stderr &
pids[2]=$!
echo "etcd 3 running: PID ${pids[2]}"

function handle_term() { 
  echo ""
  echo "ctrl+c detected, stopping etcd members"
  for pid in ${pids[*]}; do
    echo "PID $pid: stopping"
    kill -TERM "$pid" 2>/dev/null || true
    wait $pid 2>/dev/null || true
    echo "PID $pid: stopped"
  done
}

trap handle_term INT

for pid in ${pids[*]}; do
    wait $pid || true
done
