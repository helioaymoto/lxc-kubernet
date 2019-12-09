#!/bin/bash

function progress {
	echo -n " "
	while :;do for s in / - \\ \|; do printf "\b$s";sleep 1;done;done
}

function start_progress {
	progress &
	progress_pid=$!
	disown
}

function stop_progress {
	kill $progress_pid
	printf "\b \n"
}

echo -n "[1/6] Downloading rke "
start_progress
su - kubeadm -c "wget https://github.com/rancher/rke/releases/download/v1.0.0/rke_linux-amd64" >/dev/null 2>&1
stop_progress

echo "[2/6] Renaming and make executable "
su - kubeadm -c "mv rke_linux-amd64 rke"
su - kubeadm -c "chmod +x rke"

echo -n "[3/6] Installing kubernet cluster "
start_progress
su - kubeadm -c "./rke up --config ./rancher-cluster.yml" > /tmp/rke.log 2>&1
stop_progress

echo -n "[4/6] Downloading kubeadm "
start_progress
su - kubeadm -c "curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl" >/dev/null 2>&1
stop_progress

echo "[5/6] Moving to /usr/local/bin"
chmod +x /home/kubeadm/kubectl
mv /home/kubeadm/kubectl /usr/local/bin

echo "[6/6] Generating .kube/config for kubeadm"
su - kubeadm -c "mkdir .kube"
su - kubeadm -c "cp kube_config_rancher-cluster.yml .kube/config"


