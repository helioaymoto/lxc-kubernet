# lxc-kubernet Cluster
Kubernet Cluster running in a LXD/LXC containers

## About this project
This is a way to setup a Kubernet Cluster running in a single computer where it has 3 LXD/LXC containers + Kubernet Cluster. This is a good option for test propose.

## Some Observation about this project
1) The host OS has to be Ubuntu (I am running Ubuntu Ubuntu 18.04.3 LTS)... Unfortunatelly, I could not get this project working on Centos 7 host. At this time, Centos 8 is released but it´s missing some packages to allow LXD instalation via snap.
2) The LXD/LXC containers can be Ubuntu or Centos 7... In this one I am assuming Centos 7
3) LXD has to be installed via snap (via yum does not work... I think because of the lxd version)
4) LXD storage cannot be ZFS, because there is some incompatibility between Kubernet docker instalation.
5) For kubernet 1.15 above, it´s required some worked around after the containers setup (you can see in the LXC Container at /etc/rc.local)
6) At this time, the Kubernet version is v1.16.3... I cannot garantee it will work for later releases

## Step by Step to build
1) Install HOST OS (Ubuntu 18.04)
```
I have used virtual Box, but vmware should be fine too.
```
2) Install LXD/LXC
```
$ sudo systemctl enable --now snapd
$ sudo snap install lxd
$ sudo usermod -a -G lxd <username>   This allow normal user to run lxd/lxc
$ lxd init   (default configuration should be fine)
```
3) Create a Kubernet specific Profile
```
$ lxc profile show k8sprofile
config:
  limits.cpu: "2"
  limits.memory: 2GB
  limits.memory.swap: "false"
  linux.kernel_modules: ip_tables,ip6_tables,netlink_diag,nf_nat,overlay
  raw.lxc: "lxc.apparmor.profile=unconfined\nlxc.cap.drop= \nlxc.cgroup.devices.allow=a\nlxc.mount.auto=proc:rw
    sys:rw"
  security.nesting: "true"
  security.privileged: "true"
description: Default LXD profile
devices:
  eth0:
    name: eth0
    nictype: bridged
    parent: lxdbr0
    type: nic
  root:
    path: /
    pool: default
    type: disk
name: k8s
```
4) Create a LXD Storage based on directory (dir). 
```
$ lxc storage create directory dir
$ lxc storage list
+-----------+-------------+--------+--------------------------------------------------+---------+
|   NAME    | DESCRIPTION | DRIVER |                      SOURCE                      | USED BY |
+-----------+-------------+--------+--------------------------------------------------+---------+
| default   |             | zfs    | lxd-pool                                         | 2       |
+-----------+-------------+--------+--------------------------------------------------+---------+
| directory |             | dir    | /var/snap/lxd/common/lxd/storage-pools/directory | 6       |
+-----------+-------------+--------+--------------------------------------------------+---------+
```
5) You might want to have public IP for the LXC containers to have direct access to your network, so you can create an additional LXC profile to allow the container to have a second NIC
```
You need to create a bridge interface called bridge0 attached to you NIC, so you have to create the followin bridge profile
$ lxc profile show bridgeprofile
config: {}
description: Bridge networking LXD profile
devices:
  eth1:
    name: eth1
    nictype: bridged
    parent: bridge0
    type: nic
  root:
    path: /
    pool: directory
    type: disk
name: bridgeprofile
```
You should have at the end 3 differents profiles
```
$ lxc profile list
+---------------+---------+
|     NAME      | USED BY |
+---------------+---------+
| bridgeprofile | 0       |
+---------------+---------+
| default       | 0       |
+---------------+---------+
| k8sprofile    | 0       |
+---------------+---------+
```
6) Clone this project
```
git clone https://github.com/helioaymoto/lxc-kubernet.git
```
These are 3 scripts to help to setup the enviroment
create.sh: to create the LXC containers
lxc-docker.sh: to install some packages, users and docker
lxc-rke.sh to install kubernet using rke

7) Create 3 LXC containers (CENTOS 7) using create.sh script
```
$ ./create.sh kub-1 192.168.1.191
*** Starting LXD/LXC Container creation for Kubernet ***
[1/6] Starting creating LXD/LXC Containers
[2/6] Configuring public IP
[3/6] Configuring user
      Waiting network connectivity
[4/6] Installing net-tools openssh-server sshpass wget
[5/6] Installing docker
[6/6] Configuring workaround
*** Finished LXD/LXC Container creation for Kubernet ***
$ ./create.sh kub-2 192.168.1.192
*** Starting LXD/LXC Container creation for Kubernet ***
[1/6] Starting creating LXD/LXC Containers
[2/6] Configuring public IP
[3/6] Configuring user
      Waiting network connectivity
[4/6] Installing net-tools openssh-server sshpass wget
[5/6] Installing docker
[6/6] Configuring workaround
*** Finished LXD/LXC Container creation for Kubernet ***
$ ./create.sh kub-3 192.168.1.193
*** Starting LXD/LXC Container creation for Kubernet ***
[1/6] Starting creating LXD/LXC Containers
[2/6] Configuring public IP
[3/6] Configuring user
      Waiting network connectivity
[4/6] Installing net-tools openssh-server sshpass wget
[5/6] Installing docker
[6/6] Configuring workaround
*** Finished LXD/LXC Container creation for Kubernet ***
```
You should have 3 LXC containers with eth0 and eth1 NICs, where eth0 is the private/internal network and eth1 is the public network attached to the bridge in your network.
```
$ lxc list
+-------+---------+-----------------------+----------------------------------------------+------------+-----------+
| NAME  |  STATE  |         IPV4          |                     IPV6                     |    TYPE    | SNAPSHOTS |
+-------+---------+-----------------------+----------------------------------------------+------------+-----------+
| kub-1 | RUNNING | 192.168.1.191 (eth1)  | fd42:ab9e:be3:ae98:216:3eff:fee8:f1a2 (eth0) | PERSISTENT | 0         |
|       |         | 172.17.0.1 (docker0)  |                                              |            |           |
|       |         | 10.133.122.128 (eth0) |                                              |            |           |
+-------+---------+-----------------------+----------------------------------------------+------------+-----------+
| kub-2 | RUNNING | 192.168.1.192 (eth1)  | fd42:ab9e:be3:ae98:216:3eff:fe04:521a (eth0) | PERSISTENT | 0         |
|       |         | 172.17.0.1 (docker0)  |                                              |            |           |
|       |         | 10.133.122.250 (eth0) |                                              |            |           |
+-------+---------+-----------------------+----------------------------------------------+------------+-----------+
| kub-3 | RUNNING | 192.168.1.193 (eth1)  | fd42:ab9e:be3:ae98:216:3eff:fe9e:31d3 (eth0) | PERSISTENT | 0         |
|       |         | 172.17.0.1 (docker0)  |                                              |            |           |
|       |         | 10.133.122.79 (eth0)  |                                              |            |           |
+-------+---------+-----------------------+----------------------------------------------+------------+-----------+
```

8) Copy rke config file to kub-1
```
lxc file push rancher-cluster.yml kub-1/home/kubeadm/
```

9) Install kubernet with rke
```
cat lxc-rke.sh|lxc exec kub-1 bash
```

