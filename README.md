# debian-installation

This script was created for my move from windows to linux.
It contains some steps I need to initialize a new system and all packages I will try to use.

## run options

After a new installaion you need to run the script without sudo. This option adds the user to the sudoer group. You need to logout to apply these changes!

```
./install.sh -su
```

Now you can run the script for all other installation steps with sudo rights.

```
sudo ./install.sh -FLAG
```

## install options

| FLAG | Description | Comment |
| ---- | ----------- | ------- |
| help | this help | |
| test | only script tests | |
|  |  |  |
| src | debian testing (use this first) | all source repositories and base packages |
|  |  |  |
| ati | ati driver | 1 reboot,  1 run |
| nvidia | nvidia driver | 1 reboot,  2 runs |
| nvidia2 | nvidia driver official | 2 reboots, 3 runs |
|  |  |  |
| wine | Wine | |
| steam | Steam | |
| lutris | Lutris | |
| dxvk | vulkan-based compatibility layer for Direct3D | |
| dnet | Microsoft .Net 4.6.1 (do not use) | a horrible try :) |
|  |  |  |
| anbox | Anbox, a Android Emulator (very alpha) | I think this project is dead |
| atom | Atom IDE | |
| cuda | CudaText editor | many options to modify look and feel |
| discord | Discord | Chat I need |
| dream | Dreambox Edit | to handle the channels of my TV |
| java | java 8+11 jdk | Minecraft needs java 8 |
| kvm | KVM, QEMU with Virt-Manager | better than VirtualBox |
| moka | nice icon set | not tested yet |
| mozilla | Firefox + Thunderbird | |
| multimc | Minecraft MultiMC | Minecraft Launcher |
| ohmyz | ohmyz shell extension | very very powerful |
| pwsafe | Password Safe | too many secrets |
| samba | Samba | access to Windows |
| screen | XScreensaver | |
| spotify | Spotify | some music |
| twitch | twitch gui + VideoLan + Chatty | I don't like advertising |
| virtual | VirtualBox with SID library | removed from debian testing |
