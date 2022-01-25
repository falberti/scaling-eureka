#!/bin/bash

if [ $# -ne 1 ]
then
    echo "Usage: $0 <dir>"
    exit 1
fi

IMAGE_DIR=$1

# Clean-up
sudo rm -rf ${IMAGE_DIR}

# Create folder
mkdir ${IMAGE_DIR}
sudo debootstrap --arch=amd64 focal ${IMAGE_DIR}
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot debootstrap" ; exit $rc ; fi

# Set-up apt repositories
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal main restricted\" > /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal main restricted\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal-updates main restricted\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal-updates main restricted\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal universe\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal universe\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal-updates universe\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal-updates universe\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal multiverse\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal multiverse\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal-updates multiverse\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal-updates multiverse\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://security.ubuntu.com/ubuntu focal-security main restricted\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://security.ubuntu.com/ubuntu focal-security main restricted\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://security.ubuntu.com/ubuntu focal-security universe\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://security.ubuntu.com/ubuntu focal-security universe\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://security.ubuntu.com/ubuntu focal-security multiverse\" >> /etc/apt/sources.list"
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://security.ubuntu.com/ubuntu focal-security multiverse\" >> /etc/apt/sources.list"

sudo chroot ${IMAGE_DIR} /bin/bash -c "sudo apt update && sudo apt install -yq curl gnupg tcpdump ifupdown python3-pip vim screen"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot install packages" ; exit $rc ; fi

#######################################################
# EXABGP
#######################################################
echo "INSTALLING EXABGP"
sudo chroot ${IMAGE_DIR} /bin/bash -c "apt install python3-exabgp"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot install EXABGP #1" ; exit $rc ; fi
sudo chroot ${IMAGE_DIR} /bin/bash -c "mkdir -p /usr/local/var/run/exabgp"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot install EXABGP #2" ; exit $rc ; fi
sudo chroot ${IMAGE_DIR} /bin/bash -c "mkfifo /usr/local/var/run/exabgp/exabgp.{in,out}"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot install EXABGP #3" ; exit $rc ; fi
sudo chroot ${IMAGE_DIR} /bin/bash -c "chmod 600 /usr/local/var/run/exabgp/exabgp.{in,out}"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot install EXABGP #4" ; exit $rc ; fi
sudo chroot ${IMAGE_DIR} /bin/bash -c "mkdir -p /usr/local/etc/exabgp/"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot install EXABGP #5" ; exit $rc ; fi
sudo chroot ${IMAGE_DIR} /bin/bash -c "exabgp --fi > /usr/local/etc/exabgp/exabgp.env"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot install EXABGP #6" ; exit $rc ; fi
sudo chroot ${IMAGE_DIR} /bin/bash -c "sed -i 's/nobody/root/g' /usr/local/etc/exabgp/exabgp.env"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot install EXABGP #7" ; exit $rc ; fi

# Add config files
sudo cp lxd/exa/exabgp.conf ${IMAGE_DIR}/root/exabgp.conf
sudo cp lxd/exa/bgp.py ${IMAGE_DIR}/root/bgp.py

# Remove hostname
sudo rm ${IMAGE_DIR}/etc/hostname
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot remove the hostname" ; exit $rc ; fi

#######################################################
# CREATE THE METADATA
#######################################################
echo "CREATE THE METADATA"
cat << EOF > metadata.yaml
architecture: "x86_64"
creation_date: $(date +%s)
properties:
architecture: "x86_64"
description: "EXABGP image"
os: "ubuntu"
release: "20.04"
EOF
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot create the metadata" ; exit $rc ; fi

#######################################################
# CREATE THE ROOTFS
#######################################################
echo "CREATE THE ROOTFS"
sudo tar -cvzf exa.tar.gz ${IMAGE_DIR}
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot create the tar rootfs" ; exit $rc ; fi
sudo tar -cvzf exa_metadata.tar.gz metadata.yaml
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot create the tar metadata" ; exit $rc ; fi

echo "DONE"

# Exit without errors
exit 0
