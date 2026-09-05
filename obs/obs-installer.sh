#!/bin/bash

# First the Deb Multimedia repo needs to be installed
wget https://www.deb-multimedia.org/pool/main/d/deb-multimedia-keyring/deb-multimedia-keyring_2016.8.1_all.deb
sudo dpkg -i deb-multimedia-keyring_2016.8.1_all.deb

# Add a new source for APT
sudo $(EDITOR) /etc/apt/sources.list.d/deb-multimedia.list

# Add these lines for the new repo
deb http://www.deb-multimedia.org testing main non-free

# Then update your system with newer packages from the Deb Multimedia repo
sudo apt update
sudo apt upgrade

# install the OBS Studio build dependencies, now that the Deb Multimedia repo is available
#sudo apt install cmake git build-essential \
#	libmbedtls-dev libasound2-dev libavcodec-dev libavdevice-dev libavfilter-dev \
#	libavformat-dev libavutil-dev libcurl4-openssl-dev libfdk-aac-dev libfontconfig-dev \
#	libfreetype6-dev libgl1-mesa-dev libjack-jackd2-dev libjansson-dev libluajit-5.1-dev \
#	libpulse-dev libspeexdsp-dev libswresample-dev libswscale-dev libudev-dev \
#	libv4l-dev libvlc-dev libwayland-dev libx11-dev libx264-dev libxcb-shm0-dev \
#	libxcb-xinerama0-dev libxcomposite-dev libxinerama-dev pkg-config python3-dev \
#	swig libxcb-randr0-dev libxcb-xfixes0-dev libxcb-composite0-dev \
#	libx11-xcb-dev libxcb1-dev libxss-dev librist-dev libsrt-openssl-dev qt6-base-dev \
#	qt6-base-private-dev nlohmann-json3-dev libwebsocketpp-dev libasio-dev libva-dev \
#	libvpl-dev libpci-dev libqrcodegencpp-dev libdrm-dev ninja-build 

#	ccache clang clang-format cmake-curses-gui curl fdkaac fonts-noto \
#  	fonts-roboto glslang-tools glslc \
   
#	glslang-dev libcmocka-dev
#	libgles2-mesa libgles2-mesa-dev libglu1-mesa-dev 
#	libglvnd-dev libmbedtls-dev 
#	libqt6svg6-dev libshaderc-dev libsndio-dev   
#	libxaw7-dev libxcb-icccm4-dev libxcb-keysyms1-dev \
#	libxcb-util-dev libxcb-xinput-dev libxcb-xkb-dev libxcb-xtest0-dev \
#	libxkbcommon-x11-dev libxkbfile-dev libxres-dev libxtst-dev libxv-dev \
#	qt6-image-formats-plugins qt6-wayland  zsh

sudo apt install cmake ninja-build pkg-config clang clang-format build-essential curl ccache git zsh

sudo apt install swig
sudo apt install libavcodec-dev libavdevice-dev libavfilter-dev libavformat-dev libavutil-dev libswresample-dev
sudo apt install libswscale-dev libx264-dev libcurl4-openssl-dev libmbedtls-dev libgl1-mesa-dev libjansson-dev 
sudo apt install libluajit-5.1-dev python3-dev libx11-dev libxcb-randr0-dev libxcb-shm0-dev libxcb-xinerama0-dev 
sudo apt install libxcb-composite0-dev libxcomposite-dev libxinerama-dev libxcb1-dev libx11-xcb-dev libxcb-xfixes0-dev 
sudo apt install libcmocka-dev libxss-dev libglvnd-dev libgles2-mesa libgles2-mesa-dev libwayland-dev librist-dev 
sudo apt install libsrt-openssl-dev libpci-dev libpipewire-0.3-dev libqrcodegencpp-dev uthash-dev

sudo apt install qt6-base-dev qt6-base-private-dev libqt6svg6-dev qt6-wayland qt6-image-formats-plugins

sudo apt install libasound2-dev libfdk-aac-dev libfontconfig-dev libfreetype6-dev libjack-jackd2-dev libpulse-dev libsndio-dev
sudo apt install libspeexdsp-dev libudev-dev libv4l-dev libva-dev libvlc-dev libvpl-dev libdrm-dev nlohmann-json3-dev libwebsocketpp-dev libasio-dev

#sudo apt install checkinstall v4l2loopback-dkms 
#sudo apt install libqt5x11extras5-dev
#sudo apt install qt6-svg-dev 
#sudo apt install ffmpeg 
#sudo apt install nv-codec-headers

# If you want to use the browser plugin module, you need to get embedded Chrome
cd obs-studio
wget https://cdn-fastly.obsproject.com/downloads/cef_binary_5060_linux64.tar.bz2
# cef_binary_151.3.23+gd211df0+chromium-151.0.7922.170_linux64.tar.bz2
tar -xjf cef_binary_5060_linux64.tar.bz2

# Now onto actually getting OBS Studio....
git clone --recursive https://github.com/obsproject/obs-studio
cd obs-studio

# Find the particular branch or tag that you want
git branch -a
git tag -l | sort -V

# Checkout the branch or tag, such as one of
git checkout master
git checkout 32.2.2
git checkout 30.0.0-beta3
git checkout 29.1.3
git checkout 28.1.2

# A bit heavy, but clean out, and update
git reset --hard HEAD
git clean -f -f
git pull
git submodule init
git submodule update

# Clear our build directory, if there is one
rm -rf build

# The repo is now setup, so configure the build. Change to suit to taste. Also update the update the cef binary path.
# If you want to go thru the build options more easily with a menu, ccmake (note extra "c") can do it, just use it instead of cmake, such as
#cmake -S . -B build -G Ninja 
ccmake -S . -B build -G Ninja \
  	-DCEF_ROOT_DIR="cef_binary_5060_linux64/" \
	-DLINUX_PORTABLE=1 \
	-DENABLE_PIPEWIRE=1 \
  	-DENABLE_AJA=0 \
  	-DENABLE_WEBRTC=0 \
  	-DENABLE_PULSEAUDIO=1 \
  	-DENABLE_VST=1 \
  	-DENABLE_JACK=1 \
  	-DENABLE_ALSA=1 \
  	-DENABLE_HEVC=1 \
  	-DCMAKE_INSTALL_PREFIX=/usr \
	-DENABLE_BROWSER=1 \
	-DENABLE_VLC=1 \
	-DENABLE_WAYLAND=1 \
	-DENABLE_RNNOISE=1 \
	-DENABLE_SPEEXDSP=1 \
	-DENABLE_V4L2=1 \
	-DENABLE_FFMPEG_NVENC=0

#	-DENABLE_DECKLINK=0 \
# 	-DENABLE_SERVICE_UPDATES=0 \
#  -DBUILD_FOR_DISTRIBUTION=1 \
#  -DENABLE_LIBFDK=1 \
#  -DENABLE_SNDIO=0 \
#  -DOAUTH_BASE_URL="http://127.0.0.1" \
#  -DCALM_DEPRECATION=ON \
#  -DX11_Xaw_INCLUDE_PATH="/usr/include/X11/Xaw" \

# Then in ccmake, hit "c" twice to get options. Hit "t" for more pages of options. Hit "g" to generate.
# Compile it thusly. Nice to have ccache setup as it takes a pretty "long" time to build.
cmake --build build -j$(nproc)

# After the compile is done, make Debian packages
cmake --build build --target package -j$(nproc)

# Then install the Debian package, adjusting to the version number built
ls -lh build/*.deb
#sudo dpkg -i build/obs-studio-30.1.2-10-Linux.deb
sudo apt install ./obs-studio-30.1.2-10-Linux.deb

# Mark the package to be held, so it doesn't get upgraded over by the system package
sudo apt-mark hold obs-studio

# Make sure all is happy with APT
sudo apt -f install

# Then just run OBS Studio like normal (the binary gets put in /usr/bin)
obs

# Starting with version 30.0.0 (beta3 tested), you will need also do the following before building OBS Studio
sudo apt install libssl-dev
git clone --recursive https://github.com/paullouisageneau/libdatachannel
cd libdatachannel/
rm -rf build
cmake -B build -DUSE_GNUTLS=0 -DUSE_NICE=0 -DCMAKE_BUILD_TYPE=Release
cd build/
make -j$(nproc)
sudo make install




# 8800  sudo apt search obs-studio
# 8801  sudo apt remove obs-studio
# 8802  sudo apt purge obs-studio
# 8803  sudo apt autoremove

# 8863  sudo apt install cmake git checkinstall build-essential libmbedtls-dev libasound2-dev libavcodec-dev libavdevice-dev libavfilter-dev libavformat-dev libavutil-dev libcurl4-openssl-dev libfdk-aac-dev libfontconfig-dev libfreetype6-dev libgl1-mesa-dev libjack-jackd2-dev libjansson-dev libluajit-5.1-dev libpulse-dev libqt5x11extras5-dev libspeexdsp-dev libswresample-dev libswscale-dev libudev-dev libv4l-dev libvlc-dev libwayland-dev libx11-dev libx264-dev libxcb-shm0-dev libxcb-xinerama0-dev libxcomposite-dev libxinerama-dev pkg-config python3-dev qt6-svg-dev swig libxcb-randr0-dev libxcb-xfixes0-dev libxcb-shm0-dev libxcb-xinerama0-dev libxcb-composite0-dev libx11-xcb-dev libxcb1-dev libxss-dev librist-dev libsrt-openssl-dev qt6-base-dev qt6-base-private-dev nlohmann-json3-dev libwebsocketpp-dev libasio-dev libva-dev libpipewire-0.3-dev v4l2loopback-dkms libvpl-dev ffmpeg libpci-dev libqrcodegencpp-dev libdrm-dev uthash-dev libsimde-dev ninja-build extra-cmake-modules
# 8866  git/
# 8868  git clone https://github.com/FFmpeg/nv-codec-headers.git
# 8870  cd nv-codec-headers
# 8872  make
# 8874  sudo make install
# 8875  ll /usr/local/lib/pkgconfig
# 8876  ll /usr/local/include/ffnvcodec
# 8877  ..
# 8879  ll obs-studio
# 8880  rm -rf obs-studio
# 8881  git clone --recursive https://github.com/obsproject/obs-studio.git
# 8882  cd obs-studio
# 8883  wget https://cdn-fastly.obsproject.com/downloads/cef_binary_6533_linux_x86_64_v6.tar.xz
# 8887  tar -xjf cef_binary_6533_linux_x86_64_v6.tar.xz
# 8889  mkdir build
# 8890  cmake -S . -B build -G Ninja \
#                           -DOBS_CMAKE_VERSION=3 \
#                           -DCMAKE_BUILD_TYPE=RelWithDebInfo \
#                           -DCEF_ROOT_DIR="cef_binary_6533_linux_x86_64" \
#                           -DENABLE_PIPEWIRE=1 \
#                           -DENABLE_AJA=0 \
#                           -DENABLE_WEBRTC=0 \
#                           -DENABLE_PULSEAUDIO=1 \
#                           -DENABLE_VST=1 \
#                           -DENABLE_JACK=1 \
#                           -DENABLE_ALSA=1 \
#                           -DENABLE_HEVC=1 \
#                           -DCMAKE_INSTALL_PREFIX=/usr \
#                           -DENABLE_BROWSER=1 \
#                           -DENABLE_VLC=1 \
#                           -DENABLE_WAYLAND=0 \
#                           -DENABLE_RNNOISE=1 \
#                           -DENABLE_SPEEXDSP=1 \
#                           -DENABLE_V4L2=1 \
#                           -DENABLE_NVENC=1

# cmake -S . -B build -G Ninja \
#                     -DCEF_ROOT_DIR="cef_binary_5060_linux64" \
#                     -DENABLE_PIPEWIRE=1 \
#                     -DENABLE_AJA=0 \
#                     -DENABLE_WEBRTC=0 \
#                     -DENABLE_PULSEAUDIO=1 \
#                     -DENABLE_VST=1 \
#                     -DENABLE_JACK=1 \
#                     -DENABLE_ALSA=1 \
#                     -DENABLE_HEVC=1 \
#                     -DCMAKE_INSTALL_PREFIX=/usr \
#                     -DENABLE_BROWSER=1 \
#                     -DENABLE_VLC=1 \
#                     -DENABLE_WAYLAND=0 \
#                     -DENABLE_RNNOISE=1 \
#                     -DENABLE_SPEEXDSP=1 \
#                     -DENABLE_V4L2=1 \
#                     -DENABLE_NVENC=1

#                     -DLINUX_PORTABLE=0 \
#                     -DENABLE_DECKLINK=0 \
#                     -DENABLE_SERVICE_UPDATES=0 \
#                     -DBUILD_FOR_DISTRIBUTION=1 \
#                     -DENABLE_LIBFDK=1 \
#                     -DENABLE_SNDIO=0 \
#                     -DOAUTH_BASE_URL="http://127.0.0.1" \
#                     -DCALM_DEPRECATION=ON \
#                     -DX11_Xaw_INCLUDE_PATH="/usr/include/X11/Xaw" \


# 8891  ll build
# 8892  cmake --build build
# 8893  cmake --build build --target package
# 8894  ll build
# 8895  cd build
# 8897  sudo dpkg -V *.deb
# 8898  sudo gdebi
# 8899  sudo gdebi --apt-line obs-studio-32.1.0-beta2-16-gf53c843ac-Linux.deb
# 8900  sudo gdebi obs-studio-32.1.0-beta2-16-gf53c843ac-Linux.deb
# 8901  sudo ldconfig

# 8902  ll /etc/apt/sources.list.d
# 8903  history
# 8904  sudo apt-update-all.sh
# 8905  sudo apt-mark hold obs-studio
# 8906  sudo apt-update-all.sh

