#!/bin/bash

read -rp "VM Name: " vmName
read -rp "CPU Core Count: " cpuCount
read -rp "RAM Size: " ramSize
read -rp "Disk Size: " diskSize
read -rp "Iso filepath: " isoPath

isoDir="$HOME/vm/iso"
diskDir="$HOME/vm/disk"
uefiDir="$HOME/vm/uefi"
execDir="$HOME/.local/scripts"
isoFile="$(basename "$isoPath")"
ovmfFile="/usr/share/edk2/x64/OVMF_CODE.4m.fd"

mkdir -pv "$isoDir" "$diskDir" "$uefiDir" "$execDir"
cp "$isoPath" "$isoDir"/
cp "$ovmfFile" "$uefiDir"/"$vmName".4m.fd
sync
qemu-img create -f qcow2 "$diskDir"/"$vmName".qcow2 "$diskSize"

cat > "$execDir"/"$vmName".sh << EOF
qemu-system-x86_64 \\
-enable-kvm \\
-M q35 \\
-m $ramSize -smp $cpuCount -cpu host \\
-drive file=$uefiDir/$vmName.4m.fd,format=raw,if=pflash \\
-cdrom $isoDir/$isoFile \\
-drive file=$diskDir/$vmName.qcow2,format=qcow2,if=virtio \\
-usb \\
-device virtio-tablet \\
-device virtio-keyboard \\
-device qemu-xhci,id=xhci \\
-device usb-host,hostbus=1,hostport=5 \\
-device usb-host,hostbus=3,hostport=3 \\
-device usb-host,hostbus=4,hostport=3 \\
-machine vmport=off \\
-device virtio-vga-gl \\
-display sdl,gl=on \\
-device ich9-intel-hda,id=sound0,bus=pcie.0,addr=0x1b \\
-device hda-duplex,id=sound0-codec0,bus=sound0.0,cad=0 \\
-global ICH9-LPC.disable_s3=1 \\
-global ICH9-LPC.disable_s4=1 \\
-net nic,model=virtio,macaddr=52:54:00:00:00:02 \\
-net bridge,br=br0
EOF
chmod +x "$execDir"/"$vmName".sh

echo "Running first setup..."
bash "$execDir"/"$vmName".sh

qemu-img create -f qcow2 -b "$diskDir"/"$vmName".qcow2 -F qcow2 "$diskDir"/"$vmName"-1.qcow2
sed -i "\|-cdrom|d" "$execDir"/"$vmName".sh
sed -i "s|$vmName.qcow2|$vmName-1.qcow2|g" "$execDir"/"$vmName".sh
sleep 1
echo "Setup Done !"

