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
| src | debian testing (use this first) | all source repositories and base packages |
| ati | ati driver | 1 reboot,  1 run |
| nvidia | nvidia driver | 1 reboot,  2 runs |
| nvidia2 | nvidia driver official | 1 reboot, 2 runs |

**Virtualization**
| kvm | KVM, QEMU with Virt-Manager | 1 reboot, better than VirtualBox |
| virtual | VirtualBox with SID library | removed from debian testing |
| anbox | Anbox, a Android Emulator (very alpha) | I think this project is dead |

**Gaming**
| wine | Wine | |
| steam | Steam | |
| lutris | Lutris | |
| dxvk | vulkan-based compatibility layer for Direct3D | |
| dnet | Microsoft .Net 4.6.1 (do not use) | a horrible try :) |
| java | java 8+11 jdk | Minecraft needs java 8 |
| multimc | Minecraft MultiMC | Minecraft Launcher |

**Media**
| discord | Discord | Chat I need |
| dream | Dreambox Edit | to handle the channels of my TV |
| mozilla | Firefox + Thunderbird | |
| spotify | Spotify | some music |
| twitch | twitch gui + VideoLan + Chatty | I don't like advertising |

**Diverse**
| atom | Atom IDE | |
| cuda | CudaText editor | many options to modify look and feel |
| moka | nice icon set | not tested yet |
| ohmyz | ohmyz bash extension | very very powerful |
| pwsafe | Password Safe | too many secrets |
| samba | Samba | access to Windows |
| screen | XScreensaver | |

## grafic cards

Show the system info of the graphic card.

```bash
  lspci -nn | egrep -i "3d|display|vga"
```

### ATI open source

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

Add the i386 architecture.
You can check first the assembled NVIDIA grafic card. This program tell you the recommended steps.

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
