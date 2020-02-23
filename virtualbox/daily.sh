#!/bin/bash

COMMAND=$(basename $0)
DIRNAME=$(dirname $0)
GIT_ROOT=$(cd $DIRNAME/..; pwd -P)

# what to test

MININET_GIT_REPO=https://github.com/parmentelat/mininet.git
MININET_GIT_BRANCH=thierry

DISTRINET_GIT_REPO=https://github.com/parmentelat/Distrinet.git
DISTRINET_GIT_BRANCH=thierry

# the VM 
DATE=$(date +'%Y-%m-%d')
VM="distrinet-$DATE"
# XXX - hard-wired for now - search for 'findlease' in daily.md
IP=192.168.56.103
# user in the VM
USER=root 

#### base image
# *** initial entry point:
# https://www.osboxes.org/ubuntu-server/
# *** URL used as of 2020-02-20
# ubuntu-server image 

OSTYPE="Ubuntu_64"
BASE_IMAGE_URL=https://sourceforge.net/projects/osboxes/files/v/vb/59-U-u-svr/18.04/18.04.3/S18.04.3VB-64bit.7z/download
# login=osboxes
# password=osboxes.org

BASE="ubuntu"
BASE_IMAGE=$BASE.vdi


function download() {
    # the unzipped image gets stored in:
    local ORIGINAL="ubuntu-18.04.3-server-00-original"
    # see daily.md on how to tweak this in steps to end up with simply:
    local DOWNLOAD=ORIGINAL.7z
    # *** requirement on macOS
    # brew install p7zip

    [ -f ORIGINAL.vdi ] && { echo ORIGINAL.vdi OK; return 0; }

    if [ -f DOWNLOAD ]; then
        echo DOWNLOAD already here
    else
        curl -L -o DOWNLOAD ${BASE}.vdi_URL
    fi

    [ -d unwrap ] && { rm -rf unwrap; mkdir unwrap; cd unwrap; }
    7z x ../DOWNLOAD
    mv 64bit/*.vdi ../ORIGINAL.vdi
    cd ..; rm -rf unwrap
}


function provision() {

    VBoxManage createvm --name $VM --ostype $OSTYPE --register
    VBoxManage modifyvm $VM --memory 1024 --vram 128

    # copy base image
    [ -f ${BASE}.vdi ] || { echo $COMMAND needs ${BASE}.vdi; exit 1; }
    echo "copying ${BASE}.vdi into $VM.vdi"
    cp ${BASE}.vdi $VM.vdi
    # give the copy a different uuid
    VBoxManage internalcommands sethduuid $VM.vdi

    # attach virtual disk
    VBoxManage storagectl $VM --name "SATA Controller" \
        --add sata --controller IntelAHCI
    VBoxManage storageattach $VM --storagectl "SATA Controller" \
        --port 0 --device 0 --type hdd --medium $VM.vdi

    # nat network 
    VBoxManage modifyvm $VM --nic1 nat
    VBoxManage modifyvm $VM --nic2 hostonly --hostonlyadapter2 vboxnet0

}

function unprovision() {
    VBoxManage unregistervm --delete $VM
    [ -f $VM.vdi ] && rm $VM.vdi
    rm -rf ~/'VirtualBox\ VMs'/$VM
}

function start() {
    VBoxManage startvm $VM
}

function start-headless() {
    VBoxManage startvm $VM --type headless
}

function stop() {
    VBoxManage controlvm $VM poweroff
}

function wait-ssh() {
    while true; do
        echo -n "trying .. "
        if ssh -i mininet-keypair -o ConnectTimeout=1 $USER@$IP id; then
            echo OK
            break
        fi
        sleep 1
    done
}

function do-ssh () {
    ssh -i mininet-keypair $USER@$IP "$@"
}

function setup-mininet() {
    ssh -i mininet-keypair $USER@$IP << EOF
        echo '* Creating mininet git repo'
        [ -d mininet ] || git clone $MININET_GIT_REPO mininet
        echo '* Checking out branch' $MININET_GIT_BRANCH
        cd mininet
        git checkout $MININET_GIT_BRANCH
        echo '* Installing mininet'
        ./util/install.sh -a
EOF
}

function setup-distrinet() {
    ssh -i mininet-keypair $USER@$IP << EOF
        echo '* Creating distrinet git repo'
        [ -d distrinet ] || git clone $DISTRINET_GIT_REPO distrinet
        echo '* Checking out branch' $DISTRINET_GIT_BRANCH
        cd distrinet
        git checkout $DISTRINET_GIT_BRANCH
        echo '* Installing distrinet'
        python3 setup.py install -e .
EOF
}

function rsync-local-mininet() {
    echo '* Pushing local mininet sources via rsync'
    local HERE=$(pwd -P)
    # XXX that's where I have my own mininet repo
    local MININET_ROOT="$GIT_ROOT/../mininet-vanilla"
    (cd $MININET_ROOT; rsync --rsh="ssh -i $HERE/mininet-keypair" -a --relative $(git ls-files) $USER@$IP:mininet/)
    echo '* no reinstallation done...'
}

function rsync-local-distrinet() {
    echo '* Pushing local distrinet sources via rsync'
    local HERE=$(pwd -P)
    (cd $GIT_ROOT; rsync --rsh="ssh -i $HERE/mininet-keypair" -a --relative $(git ls-files) $USER@$IP:distrinet/)
    echo '* Reinstalling distrinet'
    ssh -i mininet-keypair $USER@$IP << EOF
        cd distrinet
        python3 setup.py install -e .
EOF
}


##########################################################################################

function usage() {
    echo "Usage: $COMMAND [-n vmname] {provision|unprovision}"
    exit 1
}

function main() {

    local opt
    while getopts "n:b:h" opt; do
        case "${opt}" in
            n) VM=${OPTARG} ;;
            b) BASE=${OPTARG} ;;
            *) usage ;;
        esac
    done
    shift $((OPTIND-1))

    "$@" 
}

# run with e.g.
# daily.sh provision
# daily.sh -n distrinet-2020-02-20 unprovision

main "$@"