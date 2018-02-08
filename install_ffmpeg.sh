sudo apt-get update
sudo apt-get upgrade
sudo sh -c 'echo "deb http://www.deb-multimedia.org jessie main non-free" >> /etc/apt/sources.list.d/deb-multimedia.list'
sudo sh -c 'echo "deb-src http://www.deb-multimedia.org jessie main non-free" >> /etc/apt/sources.list.d/deb-multimedia.list'
sudo apt-get update 
sudo apt-get install deb-multimedia-keyring --yes
sudo apt-get update 
sudo apt-get remove ffmpeg
sudo apt-get install build-essential libmp3lame-dev libvorbis-dev libtheora-dev libspeex-dev yasm pkg-config libfaac-dev libopenjpeg-dev libx264-dev --yes
cd /usr/src/
sudo apt-get install git --yes
sudo git clone git://git.videolan.org/x264
cd x264/
sudo ./configure --host=arm-unknown-linux-gnueabi --enable-static --disable-opencl
sudo make
sudo make install
cd /usr/src
sudo git clone https://github.com/FFmpeg/FFmpeg.git
cd FFmpeg/
sudo ./configure --arch=armel --target-os=linux --enable-gpl --enable-libx264 --enable-nonfree
sudo make -j4
sudo make install
ffmpeg -encoders # test it works
