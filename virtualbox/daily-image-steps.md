# base image

* original got from osboxes.org (see shell script for details)
* again the login and password are `osboxes` and `osboxes.org` resp.
* there were some manual tweaks needed from that point that I have not found how to automate

this is my logbook about how I actually created `ubuntu-18.04.3-server.vdi` ;
think of this document as a non-executable Dockerfile, if you prefer.

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

at that point it is convenient to turn off daily apt update ; otherwise, in the first
minutes after a node is rebooted this task will trigger and prevent ou own calls to
`apt-get install` to succeed.

```bash
systemctl disable apt-daily-upgrade.timer
systemctl disable apt-daily.timer
```

## stored in `ubuntu-18.04.3-server-03-no-daily-apt.vdi`

the osboxes image lacks some basic python3 tools

```bash
apt-get update
apt-get install -y python3-pip python3-setuptools
```

## stored in `ubuntu-18.04.3-server-04-python-setuptools.vdi`

the code - notably the test code - has hard-wired calls to `python`  that apparently
is expected to point at `python3`, so :

```bash
update-alternatives --remove python /usr/bin/python2
update-alternatives --install /usr/bin/python python /usr/bin/python3 10
```

## stored in `ubuntu-18.04.3-server-05-python3-default.vdi`

***

## `ubuntu.vdi`

the last image in this series is made the target of a symlink named `ubuntu.vdi`
which in turn is used by the daily script

***
***

on top of the `ubuntu.vdi` image, we do a `daily.sh setup-mininet`, which primarily uses

* my fork of vanilla mininet github, branch `thierry`
* ./util/install.sh -a

this of course could be redone on a daily basis but it takes a long time,
so let's cache this locally for now

this is stored in an image named `ubuntu+mininet.vdi`; one can spawn this with
```bash
daily.sh -b ubuntu+mininet provision
daily.sh start-headless
daily.sh wait-ssh
daily.sh do-ssh
```

***
***
## running `mininet`  tests

from within the `ubuntu+mininet` image:

```bash
Last login: Sun Feb 23 19:22:21 2020 from 192.168.56.1
root@osboxes:~# cd mininet/
root@osboxes:~/mininet# cd examples/test/
root@osboxes:~/mininet/examples/test# ls
runner.py              test_controllers.py  test_hwintf.py           test_linuxrouter.py  test_multipoll.py  test_numberedports.py  test_sshd.py
test_baresshd.py       test_controlnet.py   test_intfoptions.py      test_mobility.py     test_multitest.py  test_popen.py          test_tree1024.py
test_bind.py           test_cpu.py          test_limit.py            test_multilink.py    test_nat.py        test_scratchnet.py     test_treeping64.py
test_clusterSanity.py  test_emptynet.py     test_linearbandwidth.py  test_multiping.py    test_natnet.py     test_simpleperf.py     test_vlanhost.py
root@osboxes:~/mininet/examples/test# ./runner.py
..............F...................(yes/no)?
(yes/no)?
(yes/no)?
.F.EE
======================================================================
ERROR: testSpecificVLAN (test_vlanhost.testVLANHost)
Test connectivity between hosts on a specific VLAN
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/usr/lib/python3/dist-packages/pexpect/spawnbase.py", line 150, in read_nonblocking
    s = os.read(self.child_fd, size)
OSError: [Errno 5] Input/output error

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "/usr/lib/python3/dist-packages/pexpect/expect.py", line 99, in expect_loop
    incoming = spawn.read_nonblocking(spawn.maxread, timeout)
  File "/usr/lib/python3/dist-packages/pexpect/pty_spawn.py", line 465, in read_nonblocking
    return super(spawn, self).read_nonblocking(size)
  File "/usr/lib/python3/dist-packages/pexpect/spawnbase.py", line 155, in read_nonblocking
    raise EOF('End Of File (EOF). Exception style platform.')
pexpect.exceptions.EOF: End Of File (EOF). Exception style platform.

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "/root/mininet/examples/test/test_vlanhost.py", line 33, in testSpecificVLAN
    p.expect( self.prompt )
  File "/usr/lib/python3/dist-packages/pexpect/spawnbase.py", line 321, in expect
    timeout, searchwindowsize, async)
  File "/usr/lib/python3/dist-packages/pexpect/spawnbase.py", line 345, in expect_list
    return exp.expect_loop(timeout)
  File "/usr/lib/python3/dist-packages/pexpect/expect.py", line 105, in expect_loop
    return self.eof(e)
  File "/usr/lib/python3/dist-packages/pexpect/expect.py", line 50, in eof
    raise EOF(msg)
pexpect.exceptions.EOF: End Of File (EOF). Exception style platform.
<pexpect.pty_spawn.spawn object at 0x7f65a25f8128>
command: /usr/bin/python
args: [b'/usr/bin/python', b'-m', b'mininet.examples.vlanhost', b'1001']
buffer (last 100 chars): ''
before (last 100 chars): "find command 'vconfig'\r\nThe package 'vlan' is required in Ubuntu or Debian, or 'vconfig' in Fedora\r\n"
after: <class 'pexpect.exceptions.EOF'>
match: None
match_index: None
exitstatus: None
flag_eof: True
pid: 1415
child_fd: 5
closed: False
timeout: 30
delimiter: <class 'pexpect.exceptions.EOF'>
logfile: None
logfile_read: None
logfile_send: None
maxread: 2000
ignorecase: False
searchwindowsize: None
delaybeforesend: 0.05
delayafterclose: 0.1
delayafterterminate: 0.1
searcher: searcher_re:
    0: re.compile("mininet>")

======================================================================
ERROR: testVLANTopo (test_vlanhost.testVLANHost)
Test connectivity (or lack thereof) between hosts in VLANTopo
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/usr/lib/python3/dist-packages/pexpect/spawnbase.py", line 150, in read_nonblocking
    s = os.read(self.child_fd, size)
OSError: [Errno 5] Input/output error

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "/usr/lib/python3/dist-packages/pexpect/expect.py", line 99, in expect_loop
    incoming = spawn.read_nonblocking(spawn.maxread, timeout)
  File "/usr/lib/python3/dist-packages/pexpect/pty_spawn.py", line 465, in read_nonblocking
    return super(spawn, self).read_nonblocking(size)
  File "/usr/lib/python3/dist-packages/pexpect/spawnbase.py", line 155, in read_nonblocking
    raise EOF('End Of File (EOF). Exception style platform.')
pexpect.exceptions.EOF: End Of File (EOF). Exception style platform.

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "/root/mininet/examples/test/test_vlanhost.py", line 20, in testVLANTopo
    p.expect( self.prompt )
  File "/usr/lib/python3/dist-packages/pexpect/spawnbase.py", line 321, in expect
    timeout, searchwindowsize, async)
  File "/usr/lib/python3/dist-packages/pexpect/spawnbase.py", line 345, in expect_list
    return exp.expect_loop(timeout)
  File "/usr/lib/python3/dist-packages/pexpect/expect.py", line 105, in expect_loop
    return self.eof(e)
  File "/usr/lib/python3/dist-packages/pexpect/expect.py", line 50, in eof
    raise EOF(msg)
pexpect.exceptions.EOF: End Of File (EOF). Exception style platform.
<pexpect.pty_spawn.spawn object at 0x7f65a362e3c8>
command: /usr/bin/python
args: [b'/usr/bin/python', b'-m', b'mininet.examples.vlanhost']
buffer (last 100 chars): ''
before (last 100 chars): "find command 'vconfig'\r\nThe package 'vlan' is required in Ubuntu or Debian, or 'vconfig' in Fedora\r\n"
after: <class 'pexpect.exceptions.EOF'>
match: None
match_index: None
exitstatus: None
flag_eof: True
pid: 1452
child_fd: 5
closed: False
timeout: 30
delimiter: <class 'pexpect.exceptions.EOF'>
logfile: None
logfile_read: None
logfile_send: None
maxread: 2000
ignorecase: False
searchwindowsize: None
delaybeforesend: 0.05
delayafterclose: 0.1
delayafterterminate: 0.1
searcher: searcher_re:
    0: re.compile("mininet>")

======================================================================
FAIL: testLinearBandwidth (test_linearbandwidth.testLinearBandwidth)
Verify that bandwidth is monotonically decreasing as # of hops increases
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/root/mininet/examples/test/test_linearbandwidth.py", line 46, in testLinearBandwidth
    self.assertTrue( count > 0 )
AssertionError: False is not true

======================================================================
FAIL: testTree1024 (test_tree1024.testTree1024)
Run the example and do a simple ping test from h1 to h1024
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/root/mininet/examples/test/test_tree1024.py", line 28, in testTree1024
    self.assertLess( packetLossPercent, 60 )
AssertionError: 100 not less than 60

----------------------------------------------------------------------
Ran 39 tests in 820.961s

FAILED (failures=2, errors=2)
root@osboxes:~/mininet/examples/test# 
```
