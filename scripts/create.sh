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

function connectivity {
until $(curl --output /dev/null --silent --head --fail http://uol.com.br); do
    printf '.'
    sleep 5
done
echo
}


# HOSTNAME is the hostname of the LXD/LXC container
# IP is the public IP address for the container
HOSTNAME=$1
IP=$2

echo "*** Starting LXD/LXC Container creation for Kubernet ***"
echo -n "[1/6] Starting creating LXD/LXC Containers "

start_progress
lxc launch -p k8s -p bridgeprofile images:centos/7/amd64 ${HOSTNAME} --storage directory > /dev/null 2>&1
stop_progress

echo "[2/6] Configuring public IP"
lxc exec ${HOSTNAME} -- ifconfig eth1 ${IP}/24
lxc exec ${HOSTNAME} -- sh -c "cat  > /etc/sysconfig/network-scripts/ifcfg-eth1 << EOF
DEVICE=eth1
BOOTPROTO=none
ONBOOT=yes
PREFIX=24
EOF
"
lxc exec ${HOSTNAME} -- sh -c "echo  "IPADDR=${IP}" >> /etc/sysconfig/network-scripts/ifcfg-eth1"

echo "[3/6] Configuring user"
lxc exec ${HOSTNAME} -- sh -c "groupadd -g 1000 kubeadm"
lxc exec ${HOSTNAME} -- sh -c "useradd -g kubeadm -d/home/kubeadm -m -s/bin/bash kubeadm"
lxc exec ${HOSTNAME} -- sh -c "echo kubeadm | passwd --stdin root" > /dev/null 2>&1
lxc exec ${HOSTNAME} -- sh -c "echo kubeadm | passwd --stdin kubeadm" > /dev/null 2>&1

lxc exec ${HOSTNAME} -- sh -c "mkdir /home/kubeadm/.ssh"
lxc exec ${HOSTNAME} -- sh -c "chown kubeadm:kubeadm /home/kubeadm/.ssh"
lxc exec ${HOSTNAME} -- sh -c "chmod 700  /home/kubeadm/.ssh"

echo -n "      Waiting network connectivity "
connectivity

echo -n "[4/6] Installing net-tools openssh-server sshpass wget "
start_progress
lxc exec ${HOSTNAME} -- sh -c "yum install net-tools openssh-server sshpass wget -y" > /dev/null 2>&1
stop_progress
lxc exec ${HOSTNAME} -- sh -c "echo 'AllowTcpForwarding yes' >> /etc/ssh/sshd_config"
lxc exec ${HOSTNAME} -- sh -c "echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config"
lxc exec ${HOSTNAME} -- sh -c "systemctl start sshd" > /dev/null 2>&1
lxc exec ${HOSTNAME} -- sh -c "systemctl enable sshd" > /dev/null 2>&1
if [[ ${HOSTNAME} =~ .*-1.* ]]
then
        lxc exec ${HOSTNAME} -- su - kubeadm -c "ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa" > /dev/null 2>&1
        lxc exec ${HOSTNAME} -- sh -c "cat /home/kubeadm/.ssh/id_rsa.pub  >> /home/kubeadm/.ssh/authorized_keys"
        lxc exec ${HOSTNAME} -- sh -c "chown kubeadm:kubeadm /home/kubeadm/.ssh/authorized_keys"
	lxc file pull ${HOSTNAME}/home/kubeadm/.ssh/authorized_keys .
else
	lxc file push authorized_keys ${HOSTNAME}/home/kubeadm/.ssh/authorized_keys
fi
lxc exec ${HOSTNAME} -- sh -c "chown kubeadm:kubeadm /home/kubeadm/.ssh/authorized_keys"
lxc exec ${HOSTNAME} -- sh -c "chmod 644 /home/kubeadm/.ssh/authorized_keys"


echo -n "[5/6] Installing docker "
start_progress
lxc exec ${HOSTNAME} -- sh -c "yum install yum-utils device-mapper-persistent-data lvm2 -y" > /dev/null 2>&1
lxc exec ${HOSTNAME} -- sh -c "yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo" > /dev/null 2>&1
lxc exec ${HOSTNAME} -- sh -c "yum install docker-ce docker-ce-cli containerd.io -y" > /dev/null 2>&1
stop_progress

lxc exec ${HOSTNAME} -- sh -c "systemctl start docker" > /dev/null 2>&1
lxc exec ${HOSTNAME} -- sh -c "systemctl enable docker" > /dev/null 2>&1
lxc exec ${HOSTNAME} -- sh -c "usermod -aG docker kubeadm" > /dev/null 2>&1

echo "[6/6] Configuring workaround"
lxc exec ${HOSTNAME} -- sh -c "mount --make-shared /"
lxc exec ${HOSTNAME} -- sh -c "mknod /dev/kmsg c 1 11"
lxc exec ${HOSTNAME} -- sh -c "echo 'mount --make-shared /' >> /etc/rc.local"
lxc exec ${HOSTNAME} -- sh -c "echo 'mknod /dev/kmsg c 1 11' >> /etc/rc.local"
lxc exec ${HOSTNAME} -- sh -c "chmod +x /etc/rc.local"

echo "*** Finished LXD/LXC Container creation for Kubernet ***"
