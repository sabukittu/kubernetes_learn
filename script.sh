#!/bin/bash

# Basic Machine Setup
yum update -y && yum install vim wget -y
export LOCAL_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null)
hostname k8s-master
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
echo -e "$LOCAL_IP k8s-master" >>/etc/hosts
echo -e "net.ipv4.ip_forward = 1 \nnet.bridge.bridge-nf-call-iptables = 1" >>/etc/sysctl.conf
sysctl -p
export KUBECONFIG=/etc/kubernetes/admin.conf

# Docker Installation 
curl -fsSL https://get.docker.com | bash
curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
systemctl start docker
systemctl enable docker
usermod -aG docker centos

# Kubernetes Installation
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
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet

kubeadm init --apiserver-advertise-address=$LOCAL_IP --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=NumCPU
kubectl apply -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml




mkdir -p $HOME/.kube \
&& sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config \
&& sudo chown $(id -u):$(id -g) $HOME/.kube/config


