#!/bin/bash

# Update system and install required packages
apt update -y && apt upgrade -y
apt install grub2 wimtools ntfs-3g rsync wget parted -y

# Clear disk and create new GPT partition table
echo "label: gpt" | sfdisk /dev/vda

# Create two partitions (30GB each)
parted /dev/vda --script -- mklabel gpt
parted /dev/vda --script -- mkpart primary ntfs 1MB 30721MB
parted /dev/vda --script -- mkpart primary ntfs 30721MB 61441MB

# Refresh kernel partition table
partprobe
sleep 5

# Format partitions
mkfs.ntfs -f /dev/vda1
mkfs.ntfs -f /dev/vda2

echo "✅ NTFS partitions created."

# Mount first partition (bootable)
mount /dev/vda1 /mnt

# Install GRUB in BIOS (MBR) mode
grub-install --target=i386-pc --boot-directory=/mnt/boot /dev/vda

# Download wimboot to support Windows ISO boot
cd /mnt
wget https://ipxe.org/releases/wimboot

# Create GRUB config using wimboot method
mkdir -p /mnt/boot/grub
cat <<EOF > /mnt/boot/grub/grub.cfg
menuentry "Windows 10 Installer" {
    insmod part_gpt
    insmod ntfs
    insmod chain
    insmod fat
    insmod loopback
    insmod iso9660

    set root=(hd0,1)
    linux16 /wimboot
    initrd16 \\
        /bootmgr \\
        /boot/bcd \\
        /boot/boot.sdi \\
        /sources/boot.wim
}
EOF

echo "✅ GRUB config written."

# Prepare directories
cd ~
mkdir -p windisk winfile

# Mount second partition (data)
mount /dev/vda2 windisk

# Download Windows 10 ISO
wget -O win10.iso --user-agent="Mozilla/5.0" https://bit.ly/3UGzNcB

# Mount ISO and copy contents to /mnt (bootable partition)
mount -o loop win10.iso winfile
rsync -ah --progress winfile/ /mnt/
umount winfile

echo "✅ Windows files copied."

# Download VirtIO drivers ISO
wget -O virtio.iso https://bit.ly/4d1g7Ht
mount -o loop virtio.iso winfile

# Inject VirtIO drivers into boot.wim (index 2)
mkdir -p /mnt/sources/virtio
rsync -ah --progress winfile/ /mnt/sources/virtio
umount winfile

cd /mnt/sources
wimlib-imagex update boot.wim 2 --command="add /virtio /mnt/sources/virtio"

echo "✅ VirtIO drivers injected."

# Clean up
umount /mnt
umount windisk
rm -rf winfile windisk win10.iso virtio.iso

echo "🎉 DONE! Rebooting into Windows Installer..."
reboot
