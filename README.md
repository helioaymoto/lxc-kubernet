# lxc-kubernet
Kubernet Cluster running in a LXD/LXC containers

## About this project
This is a way to setup a Kubernet Cluster running in a single computer for testing propose.

## Some Observation about this project
1) The host OS has to be Ubuntu (I am running Ubuntu Ubuntu 18.04.3 LTS)... Unfortunatelly, I could not get this project working on Centos 7.
2) The LXD/LXC containers can be Ubuntu or Centos 7... In this one I am assuming Centos 7
3) LXD has to be installed via snap (via yum does not work... I think because of the lxd version)
4) For kubernet 1.15 above, it´s required some worked around after the containers setup
5) At this time, the Kubernet version is v1.16.3... I cannot garantee it will work for later releases

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
$ lxd init   (default configuration should be fine... I am using zfs storage)
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
4) You might want to have public IP for the LXC containers to have direct access to your network, so you can create an additional LXC profile to allow the container to have a second NIC
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
