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
| amd | amd/ati driver | 1 reboot |
| nvidia | nvidia driver | 1 reboot |
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
I replace the original source repositories. The original one will be saved as '/etc/apt/sources.orig'. I use the testing branch for the newest feature.

I added the sid repository! For this on we need a preferences file at '/etc/apt/preferences.d/debian-sid'. The use of sid package must be explicitly selected.

The src installation close with some basic packages.

## Grafic Cards
Show the system info of the graphic card.
```bash
  lspci -nn | egrep -i "3d|display|vga"
```

### AMD Graphic Card
No special handling. Add the i386 architecture and install all vulkan based driver and dependecies.

### NVIDIA Graphic Card
Add the i386 architecture and check first the assembled NVIDIA grafic card. This program tell you the recommended steps.
```bash
  install_lib nvidia-detect
  nvidia-detect
```

- Open Source: No special handling. Install all vulkan based driver and dependecies.
- Closed Source: **Many special handling.**

1. First you need to install Dynamic Kernel Module Support. This was part of the 'src' Flag. I got better result with this method.
2. The NVIDIA based graphic card test. (better is better)
3. Blacklist the community driver nouveau, create a new image and add gl libraries. Set the console mode for the next start and reboot.
4. Delete all old nvidia dependencies and install the proprietary driver. As part of the nvidia installation routine you should answer all of the question with 'yes' and use all recommended upgrades.
5. Reboot and have fun!

**special tip**
> When you get a problem on starting steam do following procedure.
> Delete my marker files nvidia-step1 and nvidia-step2. Repeat all these steps again and the problem with steam will bo gone.

## Virtualization
The best choise for virtualization is the KVM package. It's part of the kernel and get the best performance experience.

### KVM Installation
You need first check if your processor and board support the virtualization extension.
> Enable Intel Virtualization Technology (also known as Intel VT) or AMD-V depending on the brand of the processor.
> The virtualization extensions may be labeled Virtualization Extensions, Vanderpool or various other names depending on the OEM and system BIOS.
```bash
  grep -o 'vmx\|svm' /proc/cpuinfo
```

Now you can install all libraries. Please read the description of the difference between 'qemu:///system' and 'qemu:///session'.

[qemusystem-vs-qemusession](https://blog.wikichoon.com/2016/01/qemusystem-vs-qemusession.html)

I add the LIBVIRT_DEFAULT_URI environment variable to preselect my preference.
Once above packages are installed successfully then libvirtd service will be started automatically, run the below systemctl command to verify the status.
```bash
  systemctl status libvirtd
```

Finally I added the user to libvirtd groups and create a common directory for all my iso's.
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
