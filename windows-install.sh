#!/bin/bash

apt update -y && apt upgrade -y

apt install grub2 wimtools ntfs-3g -y

#Get the disk size in GB and convert to MB
disk_size_gb=$(parted /dev/vda --script print | awk '/^Disk \/dev\/vda:/ {print int($3)}')
disk_size_mb=$((disk_size_gb * 1024))

#Calculate partition size (25% of total size)
part_size_mb=$((disk_size_mb / 4))

#Create GPT partition table
parted /dev/vda --script -- mklabel gpt

#Create two partitions
parted /dev/vda --script -- mkpart primary ntfs 1MB ${part_size_mb}MB
parted /dev/vda --script -- mkpart primary ntfs ${part_size_mb}MB $((2 * part_size_mb))MB

#Inform kernel of partition table changes
partprobe /dev/vda

sleep 30

partprobe /dev/vda

sleep 30

partprobe /dev/vda

sleep 30 

#Format the partitions
mkfs.ntfs -f /dev/vda1
mkfs.ntfs -f /dev/vda2

echo "NTFS partitions created"

echo -e "r\ng\np\nw\nY\n" | gdisk /dev/vda

mount /dev/vda1 /mnt

#Prepare directory for the Windows disk
cd ~
mkdir windisk

mount /dev/vda2 windisk

grub-install --root-directory=/mnt /dev/vda

#Edit GRUB configuration
cd /mnt/boot/grub
cat <<EOF > grub.cfg
menuentry "windows installer" {
	insmod ntfs
	search --set=root --file=/bootmgr
	ntldr /bootmgr
	boot
}
EOF

cd /root/windisk

mkdir winfile

wget -O win10.iso --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" https://bit.ly/3UGzNcB

mount -o loop win10.iso winfile

rsync -avz --progress winfile/* /mnt

umount winfile

wget -O virtio.iso https://bit.ly/4d1g7Ht

mount -o loop virtio.iso winfile

mkdir /mnt/sources/virtio

rsync -avz --progress winfile/* /mnt/sources/virtio

cd /mnt/sources

touch cmd.txt

echo 'add virtio /virtio_drivers' >> cmd.txt

wimlib-imagex update boot.wim 2 < cmd.txt

reboot


