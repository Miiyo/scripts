#!/bin/bash

echo ""
echo "[Miyo-anarch]"
echo ""

check_available_space()
{
    settings_disk_info=$(df -h $settings_path)
    settings_available_space=$(echo $settings_disk_info | awk -v N=11 '{print $N}' | tr -d G)
    export settings_available_space 
}

settings_get_path()
{
	read -p 'Enter a path: ' settings_path

	if [ ! -d "$settings_path" ]
	then
  		mkdir $settings_path
		echo
		echo ""
		echo "$settings_path directory created!"
	fi

    export settings_path
}


settings_get_disksize()
{
	read -p 'Enter your disk size: ' settings_disksize

if [[ $settings_disksize -gt $settings_available_space ]]
	then
		echo
		echo "Not enough space!"
		echo
    	settings_get_disksize
	else
		if [[ ! $settings_disksize =~ ^[0-9]+$ ]]
		then
			echo
			echo "That's not a number!"
			echo
    		settings_get_disksize
		else
			if [ $settings_disksize -lt 4 ]
			then
				echo
				echo "Disk size needs to be larger than 4GB!"
				echo
				settings_get_disksize
			else
				export settings_disksize
			fi
		fi
	fi
}

settings_get_mountstorage()
{
	read -p 'Answer: ' settings_mountstorage

	if [ $settings_mountstorage = "yes" ]
	then
		export settings_mountstorage
	elif [ $settings_mountstorage = "no" ]
	then
		export settings_mountstorage
	else
		echo
		echo "Invalid input, type \"yes\", or \"no\"." 
		echo
		settings_get_mountstorage
	fi
}

settings_verification()
{
	read -p 'Answer: ' settings_verification_answer

	if [ $settings_verification_answer = "yes" ]
	then
		return
	elif [ $settings_verification_answer = "no" ]
	then
		echo
		echo
		echo "Exiting installation..."

        exit 1
	else
		echo
		decoration_line !
		echo "Invalid input, type \"yes\", or \"no\"."
		echo
		settings_verification
	fi
}

install_base()
{
	mkdir $settings_path/root
	cd $settings_path

	truncate -s ${settings_disksize}G disk.img
	mkfs.ext4 disk.img

	wget -O archlinuxarm.tar.gz http://sg.mirror.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz

	currentdir=${PWD##*/}
	losetup -f $settings_path/disk.img
    mountpoint=$(losetup -a | grep $currentdir | awk '{print $1}' | tr -d :)
    mount -t ext4 $mountpoint $settings_path/root

	cd $settings_path/root

	echo "Extracting the rootfs, please wait..."
	tar -xf $settings_path/archlinuxarm.tar.gz
	rm $settings_path/archlinuxarm.tar.gz
	cd $settings_path
}

netset()
{
	rm $settings_path/root/etc/resolv.conf
	echo "nameserver 8.8.8.8" > $settings_path/root/etc/resolv.conf
	echo "export HOME=/root" >> $settings_path/root/etc/profile
	echo "unset LD_PRELOAD" >> $settings_path/root/etc/profile
	echo "cd ~" >> $settings_path/root/etc/profile
}

mount()
{
	mount -o bind /dev $settings_path/root/dev
	mount -t proc proc $settings_path/root/proc
	mount -t sysfs sysfs $settings_path/root/sys
	mount -t tmpfs tmpfs $settings_path/root/tmp
	mount -t devpts devpts $settings_path/root/dev/pts
}

mount_internal()
{
	mkdir $settings_path/root/sdcard
	mount -o bind /sdcard $settings_path/root/sdcard
}

install_scripts()
{
	echo "#!/bin/bash" > $settings_path/mount_anarch
	echo "currentdir=\${PWD##*/}" >> $settings_path/mount_anarch
	echo "losetup -f disk.img" >> $settings_path/mount_anarch
	echo "mountpoint=\$(losetup -a | grep \$currentdir | awk '{print \$1}' | tr -d :)" >> $settings_path/mount_anarch
	echo "mount -t ext4 \$mountpoint root" >> $settings_path/mount_anarch
	echo "mount -o bind /dev root/dev" >> $settings_path/mount_anarch
	echo "mount -t proc  proc root/proc" >> $settings_path/mount_anarch
	echo "mount -t sysfs sysfs root/sys" >> $settings_path/mount_anarch
	echo "mount -t tmpfs tmpfs root/tmp" >> $settings_path/mount_anarch
	echo "mount -t devpts devpts root/dev/pts" >> $settings_path/mount_anarch
    if [ $settings_mountstorage = "yes" ]
	then
		echo "mount -o bind /sdcard root/sdcard" >> $settings_path/mount_anarch
	fi
	
	echo "#!/bin/bash" > $settings_path/unmount_anarch
	if [ $settings_mountstorage = "yes" ]
	then
		echo "umount -l root/sdcard" >> $settings_path/unmount_anarch
	fi	
	echo "umount -l root/dev/pts" >> $settings_path/unmount_anarch
	echo "umount -l root/tmp" >> $settings_path/unmount_anarch
	echo "umount -l root/sys" >> $settings_path/unmount_anarch
	echo "umount -l root/proc" >> $settings_path/unmount_anarch
	echo "umount -l root/dev" >> $settings_path/unmount_anarch
	echo "umount -l root" >> $settings_path/unmount_anarch
	echo "losetup -D" >> $settings_path/unmount_anarch

	echo "#!/bin/bash" > $settings_path/start_anarch
	echo "chroot root /bin/bash -l" >> $settings_path/start_anarch
}

install_misc()
{
	sed -i 's/#IgnorePkg   =/IgnorePkg   = linux-aarch64 linux-firmware/' $settings_path/root/etc/pacman.conf

	echo "#!/bin/bash" > $settings_path/root/tmp/delete_stuff
	echo "pacman -Rs linux-aarch64 linux-firmware --noconfirm" >> $settings_path/root/tmp/delete_stuff
	echo "exit" >> $settings_path/root/tmp/delete_stuff
	chroot $settings_path/root bash /tmp/delete_stuff

	echo "#!/bin/bash" > $settings_path/root/tmp/keyring_setup
	echo "pacman-key --init" >> $settings_path/root/tmp/keyring_setup
	echo "pacman-key --populate" >> $settings_path/root/tmp/keyring_setup
	echo "pacman -Sy archlinux-keyring archlinuxarm-keyring --noconfirm" >> $settings_path/root/tmp/keyring_setup
	echo "pacman -Su --noconfirm" >> $settings_path/root/tmp/keyring_setup
	echo "exit" >> $settings_path/root/tmp/keyring_setup
	chroot $settings_path/root bash /tmp/keyring_setup

	echo "#!/bin/bash" > $settings_path/root/tmp/servicectl_setup
	echo "cd /tmp" >> $settings_path/root/tmp/servicectl_setup
	echo "wget -O a.tar.gz https://github.com/selirra/servicectl/archive/1.0.tar.gz" >> $settings_path/root/tmp/servicectl_setup
	echo "tar -xf a.tar.gz -C /usr/local/lib/" >> $settings_path/root/tmp/servicectl_setup
	echo "ln -s /usr/local/lib/servicectl-1.0/servicectl /usr/local/bin/servicectl" >> $settings_path/root/tmp/servicectl_setup
	echo "ln -s /usr/local/lib/servicectl-1.0/serviced /usr/local/bin/serviced" >> $settings_path/root/tmp/servicectl_setup
	echo "rm a.tar.gz" >> $settings_path/root/tmp/servicectl_setup
	echo "exit" >> $settings_path/root/tmp/servicectl_setup
	chroot $settings_path/root bash /tmp/servicectl_setup
}

install_finished()
{
	echo ""
	echo "Installation completed!"
	echo
	echo "From now on, you can enter your chroot by running"
	echo "the mount, and start scripts in your anarch folder!"
	echo
	echo "Installer script created by: Selirra"
	echo "https://github.com/selirra"
	echo
	echo "Servicectl utility created by: Smaknsk"
	echo "https://github.com/smaknsk/servicectl"
	echo
	echo "modified to be in one script"
	echo ""
	chroot $settings_path/root /bin/bash -l
}

echo "Checking root access."
check_root

echo

echo "Where do you want to install the rootfs?"
echo "(/path/of/your/choice)"
settings_get_path

echo

echo "Checking available storage space."
check_available_space

echo

echo "Enter your virtual disk's size!"
echo "(4GB - ${settings_available_space}GB)"
settings_get_disksize

echo

echo "Do you want to mount your internal storage in the container?"
echo "(Yes / No)"
settings_get_mountstorage

echo

echo
echo "Installation path: $settings_path"
echo "Virtual disk size: ${settings_disksize}GB"
echo "Mount internal storage: $settings_mountstorage"

echo
echo "Are these settings correct?"
echo "(Yes / No)"
settings_verification

echo

echo "Starting installation..."
echo "Do not turn off your device!"
install_base

echo

echo "Setting up your profile..."
install_profile

echo

echo "Mounting the filesystem..."
install_mount

echo

if [ $settings_mountstorage = "yes" ]
then
    echo "Mounting the filesystem..."
    install_mount_internal
fi


echo

echo "Creating startup scripts..."
install_scripts

echo

echo "Setting up the package manager..."
install_misc

echo

install_finished
