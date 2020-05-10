# debian-installation

This script was created for my move from windows to linux.
It contains some steps I need to initialize a new system and all packages I will try to use.

## run options

After a new installaion you need to run the script without sudo.

This option adds the user to the sudoer group. You need to logout to apply these changes!

```bash
  chmod +x ./install.sh
  ./install.sh su
```

Now you can run the script for all other installation steps with sudo rights.

```bash
  sudo ./install.sh FLAG    # also with -FLAG
```

## install options
You can use a sign with the flags, but you don't need this.

| FLAG | Description | Comment |
| ---- | ----------- | ------- |
| help | this help | |
| test | only script tests | |

**System**
| FLAG | Description | Comment |
| ---- | ----------- | ------- |
| src | debian testing (use this first) | all source repositories and base packages |
| amd | amd/ati driver | 1 reboot,  1 run |
| nvidia | nvidia driver | 1 reboot,  2 runs |
| nvidia2 | nvidia driver official | 1 reboot, 2 runs |

**Virtualization**
| FLAG | Description | Comment |
| ---- | ----------- | ------- |
| kvm | KVM, QEMU with Virt-Manager | 1 reboot, better than VirtualBox |
| virtual | VirtualBox with SID library | removed from debian testing |
| anbox | Anbox, a Android Emulator (very alpha) | I think this project is dead |

**Gaming**
| FLAG | Description | Comment |
| ---- | ----------- | ------- |
| wine | Wine | |
| steam | Steam | |
| lutris | Lutris | |
| dxvk | vulkan-based compatibility layer for Direct3D | |
| dnet | Microsoft .Net 4.6.1 (do not use) | a horrible try :) |
| java | java 8+11 jdk | Minecraft needs java 8 |
| multimc | Minecraft MultiMC | Minecraft Launcher |

**Media**
| FLAG | Description | Comment |
| ---- | ----------- | ------- |
| discord | Discord | Chat I need |
| dream | Dreambox Edit | to handle the channels of my TV |
| mozilla | Firefox + Thunderbird | |
| spotify | Spotify | some music |
| twitch | twitch gui + VideoLan + Chatty | I don't like advertising |

**Diverse**
| FLAG | Description | Comment |
| ---- | ----------- | ------- |
| atom | Atom IDE | |
| cuda | CudaText editor | many options to modify look and feel |
| moka | nice icon set | not tested yet |
| ohmyz | ohmyz bash extension | very very powerful |
| pwsafe | Password Safe | too many secrets |
| samba | Samba | access to Windows |
| screen | XScreensaver | |

## Source Repositories
I replace the original source repositories. The original one will be saved as '/etc/apt/sources.orig'. I will use the testing branch for the newest feature.
```
  deb     http://deb.debian.org/debian               testing          main contrib non-free
  deb-src http://deb.debian.org/debian               testing          main contrib non-free

  deb     http://deb.debian.org/debian               testing-updates  main contrib non-free
  deb-src http://deb.debian.org/debian               testing-updates  main contrib non-free

  deb     http://security.debian.org/debian-security testing-security main contrib non-free
  deb-src http://security.debian.org/debian-security testing-security main contrib non-free

  deb     http://deb.debian.org/debian/              sid              main non-free contrib
  deb-src http://deb.debian.org/debian/              sid              main non-free contrib
```

I added the sid repository! For this on we need a preferences file at '/etc/apt/preferences.d/debian-sid'. The use of sid package must be explicitly selected.
```
  Package: *
  Pin: release n=testing
  Pin-Priority: 900

  Package: *
  Pin: release n=sid
  Pin-Priority: -10
```

The src installation close with some basic packages.
```bash
  apt install apt-transport-https			# enables the usage of https with deb's
  apt install firmware-linux-nonfree
  apt install linux-headers-$(uname -r | sed 's/[^-]*-[^-]*-//')
  apt install build-essential				# all packages needed to compile package
  apt install dkms							# Dynamic Kernel Module Support
```

## Grafic Cards
Show the system info of the graphic card.
```bash
  lspci -nn | egrep -i "3d|display|vga"
```

### AMD open source
No special handling. Add the i386 architecture and install all vulkan based driver and dependecies.
```bash
  dpkg --add-architecture i386
  apt install xserver-xorg-video-amdgpu
  apt install libgl1-mesa-dri libgl1-mesa-dri:i386
  apt install libgl1-mesa-glx libgl1-mesa-glx:i386
  apt install mesa-vulkan-drivers mesa-vulkan-drivers:i386
  apt install libvulkan1 libvulkan1:i386
  apt install vulkan-utils

  systemctl reboot
```

### NVIDIA open source
You can check first the assembled NVIDIA grafic card. This program tell you the recommended steps.
```bash
  install_lib nvidia-detect
  nvidia-detect
```

No special handling. Add the i386 architecture and install all vulkan based driver and dependecies.
```bash
  dpkg --add-architecture i386
  apt install nvidia-driver
  apt install libgl1-mesa-dri libgl1-mesa-dri:i386
  apt install libgl1-mesa-glx libgl1-mesa-glx:i386
  apt install mesa-vulkan-drivers mesa-vulkan-drivers:i386
  apt install libvulkan1 libvulkan1:i386
  apt install vulkan-utils
  systemctl reboot
```

### NVIDIA closed source
First you add the i386 architecture. You can check first the assembled NVIDIA grafic card. This program tell you the recommended steps.
```bash
  dpkg --add-architecture i386
  install_lib nvidia-detect
  nvidia-detect
```

**Many special handling.**

1. First you need to install Dynamic Kernel Module Support. This was part of the 'src' Flag. I got better result with this tool.
```bash
  apt install linux-headers-$(uname -r | sed 's/[^-]*-[^-]*-//')
  apt install build-essential
  apt install dkms
```

2. The NVIDIA based graphic card test. (better is better)
```bash
  install_lib nvidia-detect
  nvidia-detect
```

3. Blacklist the community driver nouveau, create a new image and add gl libraries. Set the console mode for the next start and reboot.
```bash
  # first run of 'sudo install.sh nvidia2'

  cat <<- EOT > /etc/modprobe.d/blacklist-nvidia-nouveau.conf
    blacklist nouveau
    options nouveau modeset=0
    EOT

  update-initramfs -u

  apt install libgl1-mesa-dri libgl1-mesa-dri:i386
  apt install libgl1-mesa-glx libgl1-mesa-glx:i386

  systemctl set-default multi-user.target
  systemctl reboot
```

4. Delete all old nvidia dependencies and install the proprietary driver.
As part of the nvidia installation routine you should answer all of the question with 'yes' and use all recommended upgrades.
```bash
  # second run of 'sudo install.sh nvidia2'

  apt remove '^nvidia.*'
  sh $NVIDIA_DRV         # current NVIDIA-Linux-x86_64-440.82.run

  apt install mesa-vulkan-drivers mesa-vulkan-drivers:i386
  apt install libvulkan1 libvulkan1:i386
  apt install vulkan-utils

  systemctl set-default graphical.target
  systemctl reboot
```

5. have fun

**special tip**

When you get a problem on starting steam do following procedure.
Delete my marker files nvidia-step1 and nvidia-step2. Repeat all these steps again and the problem with steam will bo gone.

## Virtualization
The best choise for virtualization is the KVM package. It's part of the kernel and get the best performance experience.

### KVM Installation
You need first check if your processor and board support the virtualization extension.
Enable Intel Virtualization Technology (also known as Intel VT) or AMD-V depending on the brand of the processor.
The virtualization extensions may be labeled Virtualization Extensions, Vanderpool or various other names depending on the OEM and system BIOS.
```bash
  grep -o 'vmx\|svm' /proc/cpuinfo
```

Now you can install all libraries.
```bash
  apt install qemu-kvm
  apt install libvirt-clients libvirt-daemon libvirt-daemon-system
  apt install libguestfs-tools libosinfo-bin bridge-utils geinisoimage
  apt install virtinst virt-viewer virt-manager
```

Please read the description of the difference between 'qemu:///system' and 'qemu:///session'.

[qemusystem-vs-qemusession](https://blog.wikichoon.com/2016/01/qemusystem-vs-qemusession.html)

I add the LIBVIRT_DEFAULT_URI environment variable to preselect my preference.
```bash
  add_export_env '.bashrc' 'LIBVIRT_DEFAULT_URI' 'qemu:///system'
  add_export_env '.zshrc'  'LIBVIRT_DEFAULT_URI' 'qemu:///system'
```

Once above packages are installed successfully then libvirtd service will be started automatically, run the below systemctl command to verify the status.
```bash
  systemctl status libvirtd
```

Finally I added the user to libvirtd groups and create a common directory for all my iso's.
```bash
  adduser $SUDO_USER libvirt
  adduser $SUDO_USER libvirt-qemu

  mkdir /media/data/iso
  chown -R $SUDO_USER:$SUDO_USER /media/data
```

Now you should reboot your system.

### Network Bridging
The best choise for network connection from a virtual machine to the internet gets a network bridge. I follow the guide based in this video.

[Network Bridging for Virtual Machine Manager](https://www.youtube.com/watch?v=rSxK_08LSZw)

It was demonstrated on a Fedora distibution but works very well on Debian.

## Gaming

### Wine

### Steam

### Lutris

### DXVK
