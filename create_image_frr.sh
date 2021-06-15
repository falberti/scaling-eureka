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
sudo debootstrap --arch=amd64 bionic ${IMAGE_DIR}
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot debootstrap" ; exit $rc ; fi

sudo chroot ${IMAGE_DIR} /bin/bash -c "sudo apt update && sudo apt install -yq curl gnupg tcpdump ifupdown"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot install curl" ; exit $rc ; fi

#######################################################
# FRR (taken from https://deb.frrouting.org)
#######################################################
echo "INSTALLING FRR"
sudo chroot ${IMAGE_DIR} /bin/bash -c "curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute FRR command #1" ; exit $rc ; fi
# possible values for FRRVER: frr-6 frr-7 frr-stable
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo deb https://deb.frrouting.org/frr $(lsb_release -s -c) frr-stable | sudo tee -a /etc/apt/sources.list.d/frr.list"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute FRR command #2" ; exit $rc ; fi
sudo chroot ${IMAGE_DIR} /bin/bash -c "sudo apt update && sudo apt install -yq frr frr-rpki-rtrlib librtr-dev librtr0 rtr-tools frr-pythontools"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute FRR command #3" ; exit $rc ; fi

#######################################################
# CONFIGURE THE ROOTFS
#######################################################
echo "CONFIGURE THE ROOTFS"
# Add library path
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"include /etc/ld.so.conf.d/*.conf\" > /etc/ld.so.conf"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #4" ; exit $rc ; fi
sudo chroot ${IMAGE_DIR} /bin/bash -c "echo \"include /usr/local/lib\" >> /etc/ld.so.conf"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #5" ; exit $rc ; fi

# Configure sysctl FRR
sudo cp lxd/frr/zebra.service ${IMAGE_DIR}/lib/systemd/system/
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #6" ; exit $rc ; fi
sudo cp lxd/frr/bgpd.service ${IMAGE_DIR}/lib/systemd/system/
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #7" ; exit $rc ; fi
sudo cp lxd/frr/ospfd.service ${IMAGE_DIR}/lib/systemd/system/
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #8" ; exit $rc ; fi

# Required configuration files
sudo mkdir -p ${IMAGE_DIR}/etc/frr/
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #9" ; exit $rc ; fi
sudo touch ${IMAGE_DIR}/etc/frr/zebra.conf
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #10" ; exit $rc ; fi
sudo touch ${IMAGE_DIR}/etc/frr/bgpd.conf
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #11" ; exit $rc ; fi
sudo touch ${IMAGE_DIR}/etc/frr/ospf.conf
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #12" ; exit $rc ; fi
sudo mkdir -p ${IMAGE_DIR}/usr/local/etc
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #13" ; exit $rc ; fi
sudo touch ${IMAGE_DIR}/usr/local/etc/vtysh.conf
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #14" ; exit $rc ; fi

# Start FRR at boot
sudo chroot ${IMAGE_DIR} /bin/bash -c "/bin/systemctl enable zebra.service"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #15" ; exit $rc ; fi
sudo chroot ${IMAGE_DIR} /bin/bash -c "/bin/systemctl enable bgpd.service"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #16" ; exit $rc ; fi
sudo chroot ${IMAGE_DIR} /bin/bash -c "/bin/systemctl enable ospfd.service"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #17" ; exit $rc ; fi

# Remove hostname
sudo rm ${IMAGE_DIR}/etc/hostname
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #18" ; exit $rc ; fi
sudo /bin/bash -c "echo \"ldconfig\" >> ${IMAGE_DIR}/root/.bashrc"
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot execute command #19" ; exit $rc ; fi

#######################################################
# CREATE THE METADATA
#######################################################
echo "CREATE THE METADATA"
cat << EOF > metadata.yaml
architecture: "x86_64"
creation_date: $(date +%s)
properties:
architecture: "x86_64"
description: "FRR image"
os: "ubuntu"
release: "18.04"
EOF
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot create the metadata" ; exit $rc ; fi

#######################################################
# CREATE THE ROOTFS
#######################################################
echo "CREATE THE ROOTFS"
sudo tar -cvzf frr.tar.gz ${IMAGE_DIR} metadata.yaml
rc=$?; if [ $rc -ne 0 ]; then echo "Cannot create the rootfs" ; exit $rc ; fi

echo "DONE"

# Exit without errors
exit 0
