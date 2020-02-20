# base image

* original got from osboxes.org (see shell script for details)
* again the login and password are `osboxes` and `osboxes.org` resp.
* there were some manual tweaks needed from that point that I have not found how to automate

***

## starting from  `ubuntu-18.04.3-server-00-original.vdi`

```bash
sudo cat >> /etc/netplan/50-cloud-init.yaml << EOF
    renderer: networkd
    ethernets:
       enp0s3:
           dhcp4: yes
       enp0s8:
           dhcp4: yes
EOF
sudo netplan apply
```

at that point we have outside connectivity; typical setup (may depend of course) I observe is

| VB nic number | VB type  | ubuntu interface name | IP address |
|---------------|----------|----------------|----------------|
| 1             | nat      | enp0s3         | 10.0.2.15      |
| 2             | hostonly | enp0s8         | 192.168.56.103 |

***

## stored in `ubuntu-18.04.3-server-01-network.vdi`

```bash
# from the VirtualBox terminal
sudo apt-get update
sudo apt-get install openssh-server
cd
mkdir .ssh
chmod 700 .ssh
```

at that point we have ssh connectivity through password auth; **NOTE** on my setup
I need to cancel out a global ssh setting to enable password mode

```bash
# just checking access as osboxes through password
ssh -o BatchMode=no osboxes@192.168.56.103 id
```

so we can grant public-key access

```bash
# granting access to osboxes
scp -o BatchMode=no mininet-keypair.pub osboxes@192.168.56.103:.ssh/authorized_keys
```

and so use ssh in batch mode

```bash
# just checking access to osboxes with pubkey
ssh -o BatchMode=yes -i mininet-keypair osboxes@192.168.56.103 id
```

from that point it is easy to grant access to root as well

```bash
# granting access to root
ssh -o BatchMode=yes -i mininet-keypair osboxes@192.168.56.103
sudo cp /home/osboxes/.ssh/authorized_keys /root/.ssh/authorized_keys
```

```bash
# just checking access to root with pubkey
ssh -o BatchMode=yes -i mininet-keypair root@192.168.56.103 id
```

## stored in `ubuntu-18.04.3-server-02-ssh.vdi`

the last image in this series must be the target of a symlink named

## `ubuntu-18.04.3-server.vdi` 

which in turn is used by the daily script