#!/bin/bash

# Update system and install required tools
apt update -y && apt upgrade -y
apt install grub2 wimtools ntfs-3g rsync wget parted -y

# Clear previous partitions (WARNING: Data loss)
echo "label: gpt" | sfdisk /dev/vda

# Create two 30GB NTFS partitions (approx 30720MB each)
parted /dev/vda --script -- mklabel gpt
parted /dev/vda --script -- mkpart primary ntfs 1MB 30721MB
parted /dev/vda --script -- mkpart primary ntfs 30721MB 61441MB

# Let kernel update partition table
partprobe
sleep 5

# Format partitions
mkfs.ntfs -f /dev/vda1
mkfs.ntfs -f /dev/vda2

echo "✅ NTFS partitions created."

# Mount first partition and install GRUB
mount /dev/vda1 /mnt
grub-install --target=i386-pc --boot-directory=/mnt/boot /dev/vda

# Create GRUB config to boot Windows
cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "Boot Windows Installer" {
    insmod ntfs
    insmod chain
    search --no-floppy --set=root --file /bootmgr
    chainloader /bootmgr
}
EOF

echo "✅ GRUB configuration created."

# Prepare directories
cd ~
mkdir -p windisk winfile
mount /dev/vda2 windisk

# Download Windows ISO
wget -O win10.iso --user-agent="Mozilla/5.0" https://bit.ly/3UGzNcB

# Mount ISO and copy contents to bootable partition
mount -o loop win10.iso winfile
rsync -ah --progress winfile/ /mnt/
umount winfile

echo "✅ Windows ISO content copied to /dev/vda1."

# Download VirtIO driver ISO
wget -O virtio.iso https://bit.ly/4d1g7Ht
mount -o loop virtio.iso winfile

# Inject VirtIO drivers into boot.wim
mkdir -p /mnt/sources/virtio
rsync -ah --progress winfile/ /mnt/sources/virtio
umount winfile

# Inject VirtIO drivers (boot.wim index 2)
cd /mnt/sources
wimlib-imagex update boot.wim 2 --command="add /virtio /mnt/sources/virtio"

echo "✅ VirtIO drivers injected into boot.wim."

# Cleanup
umount /mnt
umount windisk
rm -rf winfile windisk win10.iso virtio.iso

echo "✅ Setup completed. Rebooting into Windows installer..."
reboot
