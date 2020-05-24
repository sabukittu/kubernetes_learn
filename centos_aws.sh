#!/usr/bin/env bash

## Desc: This script is to configure AWS CentOS 7 as Kubernetes Master or node 
## Author : Esskay 

set -e

if [[ ! -e /etc/yum.repos.d/kubernetes.repo ]]; then
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF
fi

ARG1=$1

common () {
  ## Basic Machine Setup
  yum update -y && yum install git vim wget -y
  export LOCAL_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)
  setenforce 0
  sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
  echo -e "net.ipv4.ip_forward = 1 \nnet.bridge.bridge-nf-call-iptables = 1" >>/etc/sysctl.conf
  if [[ $ARG1 == 'master' ]]; then
    echo -e "$LOCAL_IP k8-master" >>/etc/hosts
    hostname k8-master
  else 
    echo -e "$LOCAL_IP k8-node" >>/etc/hosts
    hostname k8-node
  fi

  ## Docker Installation 
  curl -fsSL https://get.docker.com | bash
  curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
  systemctl start docker
  systemctl enable docker
  usermod -aG docker centos

  ## Kubernetes Installation
  yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
  systemctl enable --now kubelet
  sysctl -p
}

master () {
  export KUBECONFIG=/etc/kubernetes/admin.conf
  kubeadm init --apiserver-advertise-address=$LOCAL_IP --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU && sleep 30
  kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml
  mkdir -p $HOME/.kube \
    && cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
}

case $1 in
  'master')
    common
    master
    ;;
  'node')
    common
    ;;
  'master-init')
    master
    ;;
  'join-cmd')
    kubeadm token create --print-join-command
    ;;
  *)
    echo "$0 <'master' or 'node'>"
    exit 1
    ;;
esac
