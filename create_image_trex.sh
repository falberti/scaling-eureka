#!/bin/bash

if [ $# -ne 1 ]
then
    echo "Usage: $0 <dir>"
    exit 1
fi

IMAGE_DIR=$1

# Clean-up
rm -rf ${IMAGE_DIR}

# Create folder
mkdir ${IMAGE_DIR}
debootstrap --arch=amd64 focal ${IMAGE_DIR}
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot debootstrap" ; exit $rc ; fi

# Set-up apt repositories
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal main restricted\" > /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal main restricted\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal-updates main restricted\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal-updates main restricted\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal universe\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal universe\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal-updates universe\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal-updates universe\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal multiverse\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal multiverse\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal-updates multiverse\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal-updates multiverse\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://security.ubuntu.com/ubuntu focal-security main restricted\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://security.ubuntu.com/ubuntu focal-security main restricted\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://security.ubuntu.com/ubuntu focal-security universe\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://security.ubuntu.com/ubuntu focal-security universe\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb http://security.ubuntu.com/ubuntu focal-security multiverse\" >> /etc/apt/sources.list"
chroot ${IMAGE_DIR} /bin/bash -c "echo \"deb-src http://security.ubuntu.com/ubuntu focal-security multiverse\" >> /etc/apt/sources.list"

chroot ${IMAGE_DIR} /bin/bash -c "apt update && apt install -yq wget net-tools netbase strace iproute2 iputils-ping pciutils curl gnupg tcpdump ifupdown python3-pip vim screen"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot install packages" ; exit $rc ; fi

#######################################################
# TRex
#######################################################
echo "INSTALLING TRex"
chroot ${IMAGE_DIR} /bin/bash -c "wget --no-check-certificate https://trex-tgn.cisco.com/trex/release/v2.89.tar.gz"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot get TRex" ; exit $rc ; fi
chroot ${IMAGE_DIR} /bin/bash -c "tar -zxvf v2.89.tar.gz -C /"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot untar TRex archive" ; exit $rc ; fi
chroot ${IMAGE_DIR} /bin/bash -c "chown root:root /v2.89"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot set permissions to TRex folder" ; exit $rc ; fi
chroot ${IMAGE_DIR} /bin/bash -c "rm v2.89.tar.gz"
rc=$?; if [ $rc -ne 0 ]; then echo "Canno remove archive" ; exit $rc ; fi
chroot ${IMAGE_DIR} /bin/bash -c "mv v2.89 trex"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot rename TRex folder" ; exit $rc ; fi

# Remove hostname
rm ${IMAGE_DIR}/etc/hostname
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
description: "TRex image"
os: "ubuntu"
release: "20.04"
EOF
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot create the metadata" ; exit $rc ; fi

#######################################################
# CREATE THE ROOTFS
#######################################################
echo "CREATE THE ROOTFS"
sudo tar -cvzf trex.tar.gz ${IMAGE_DIR}
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot create the rootfs" ; exit $rc ; fi
sudo tar -cvzf trex_metadata.tar.gz metadata.yaml
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot create the tar metadata" ; exit $rc ; fi

echo "DONE"

exit 0
