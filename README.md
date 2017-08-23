# Static builds (update 2017/08/23)

Maybe you may save time by using the static builds found here: [https://www.johnvansickle.com/ffmpeg/](https://www.johnvansickle.com/ffmpeg/)

# FFmpeg on Raspberry Pi 3 with h264 support (2017/01/23)

Steps below are a combination of these 2 sources:
 - [https://www.assetbank.co.uk/support/documentation/install/ffmpeg-debian-squeeze/ffmpeg-debian-jessie/](https://www.assetbank.co.uk/support/documentation/install/ffmpeg-debian-squeeze/ffmpeg-debian-jessie/)
 - [http://www.jeffreythompson.org/blog/2014/11/13/installing-ffmpeg-for-raspberry-pi/](http://www.jeffreythompson.org/blog/2014/11/13/installing-ffmpeg-for-raspberry-pi/)
 
Raspberry Pi 3 Model B with [Raspbian Jessie Lite 2017-01-11](http://vx2-downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2017-01-10/2017-01-11-raspbian-jessie-lite.zip)

```bash
sudo apt-get update
sudo apt-get upgrade
sudo sh -c 'echo "deb http://www.deb-multimedia.org jessie main non-free" >> /etc/apt/sources.list.d/deb-multimedia.list'
sudo sh -c 'echo "deb-src http://www.deb-multimedia.org jessie main non-free" >> /etc/apt/sources.list.d/deb-multimedia.list'
sudo apt-get update 
sudo apt-get install deb-multimedia-keyring
sudo apt-get update 
sudo apt-get remove ffmpeg
sudo apt-get install build-essential libmp3lame-dev libvorbis-dev libtheora-dev libspeex-dev yasm pkg-config libfaac-dev libopenjpeg-dev libx264-dev
cd /usr/src/
sudo apt-get install git
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
```

# Install and test ffmpeg on Raspberry Pi 3 (with Docker)

Docker containers were used, so ffmpeg was not installed directly on the RPi. The docker image has been pushed to [https://hub.docker.com/r/tgogos/ffmpeg/](https://hub.docker.com/r/tgogos/ffmpeg/), you can save time by pulling it and then start testing... If you'd like to reproduce the whole process take a look at the section below "Download ffmpeg source code / compile"


## Test environment
 - Raspberry Pi 3
 - Host OS: Raspbian Jessie Lite image (downloaded [2016-09-23-raspbian-jessie-lite.zip](http://director.downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2016-09-28/2016-09-23-raspbian-jessie-lite.zip) from the official site)
 - Docker image to start with (FROM): `resin/rpi-raspbian:jessie-20160831`
 - Video file: Big Buck Bunny by Blender Foundation [https://www.youtube.com/watch?v=YE7VzlLtp-4](https://www.youtube.com/watch?v=YE7VzlLtp-4)

## Download ffmpeg source code / compile
`* Beware that this compilation procedure takes a few hours to finish`


```bash
apt-get update
apt-get upgrade
apt-get install git
git clone git://source.ffmpeg.org/ffmpeg.git
cd ffmpeg
apt-get install build-essential
apt-get install pkg-config
./configure
make
make install
```


## 1. Test with Docker & without OVS
```bash

+------------------------+              +------------------------+ 
|       Raspberry Pi     |              |          Demo PC       |
|                        |              |                        |
|  +------------------+  |              |                        |
|  | Docker Container |  |              |                        |
|  +------------------+  |              |                        |
|            |           |              |                        |
+------------------------+              +------------------------+
             |                                       |               
             +------------------->-------------------+


# STEP 1 - Raspberry Pi (eth0: 10.143.0.246):
# big_buck_bunny.mp4 is not provided within the docker image
# if it is available on the docker host (RPi), use `docker cp...` to copy it inside the image
ffmpeg -re -i big_buck_bunny.mp4 -vcodec mpeg4 -an -b 1024k -s 640x480 -f mpegts udp:10.143.0.245:9999?pkt_size=1316

# STEP 2 - Demo pc (eth0: 10.143.0.245):
ffplay udp://10.143.0.246:9999
```


## 2. Test with Docker & OVS
Open vSwitch must be installed on the docker host which is the Raspberry Pi, not on any other docker container. Network configuration comes from this source: [https://developer.ibm.com/recipes/tutorials/using-ovs-bridge-for-docker-networking/](https://developer.ibm.com/recipes/tutorials/using-ovs-bridge-for-docker-networking/)
```bash

+------------------------+              +------------------------+ 
|       Raspberry Pi     |              |          Demo PC       |
|                        |              |                        |
|  +------------------+  |              |                        |
|  | Docker Container |  |              |                        |
|  +------------------+  |              |                        |
|            |           |              |                        |
|  +------------------+  |              |                        |
|  |   Open vSwitch   |  |              |                        |
|  +------------------+  |              |                        |
|            |           |              |                        |
+------------------------+              +------------------------+
             |                                       |               
             +------------------->-------------------+


# first add and configure the bridge
sudo ovs-vsctl add-br ovs-br1
sudo ifconfig ovs-br1 192.168.0.1 netmask 255.255.255.0 up
export pubintf=eth0
export priintf=ovs-br1
sudo iptables -t nat -A POSTROUTING -o $pubintf -j MASQUERADE
sudo iptables -A FORWARD -i $priintf -j ACCEPT
sudo iptables -A FORWARD -i $priintf -o $pubintf -m state --state RELATED,ESTABLISHED -j ACCEPT

# then, run a container without network
docker run --net=none --name=ffmpeg_nonet_privileged --privileged -itd tgogos/ffmpeg:latest
docker exec ffmpeg_nonet_privileged ifconfig # this should print out only 'lo'

# add a NIc
sudo ovs-docker add-port ovs-br1 eth0 ffmpeg_nonet_privileged --ipaddress=192.168.0.2/24 --gateway=192.168.0.1
docker exec ffmpeg_nonet_privileged ifconfig # this should print out 'lo' and 'eth0'

# test (RPi: 10.143.0.246, Demo pc: 10.143.0.245)
# big_buck_bunny.mp4 is not provided within the docker image
# if it is available on the docker host (RPi), use `docker cp...` to copy it inside the image
docker attach ffmpeg_nonet_privileged
ffmpeg -re -i big_buck_bunny.mp4 -vcodec mpeg4 -an -b 1024k -s 640x480 -f mpegts udp:10.143.0.245:9999?pkt_size=1316
ffplay udp://10.143.0.246:9999 # for the Demo pc



# commands you might need later...
sudo iptables --flush
sudo ovs-vsctl del-br name_of_bridge
```



## 3. Test with Docker (as transcoder)
```bash

+------------------------+              +------------------------+ 
|       Raspberry Pi     |              |          Demo PC       |
|                        |              |                        |
|  +------------------+  |              |                        |
|  | Docker Container |  |              |                        |
|  +------------------+  |              |                        |
|            |           |              |                        |
+------------------------+              +------------------------+
             |                                       |               
             +--------------(1)--<-------------------+
             |                                       |
             +--------------(2)-->-------------------+

# 1 - Demo PC sends a video
# 2 - Docker container with ffmpeg transcodes it and sends it back


# STEP 1 - Demo pc (eth0: 10.143.0.245):
# start sending the video file at udp port 9999...
ffmpeg -re -i big_buck_bunny.mp4 -vcodec mpeg4 -an -b 1024k -s 640x480 -f mpegts udp://10.143.0.246:9999?pkt_size=1316


# STEP 2 - Raspberry Pi (eth0: 10.143.0.246):
# run a container and expose udp port 9999
docker run -itd --name=ffmpegTranscoder -p 9999:9999/udp tgogos/ffmpeg
docker attach ffmpegTranscoder
# send back through udp port 9998 
ffmpeg -re -i udp:10.143.0.245:9999 -vcodec mpeg4 -b:v 2048 -f mpegts udp:10.143.0.245:9998?pkt_size=1316


# STEP 3 - Demo pc (eth0: 10.143.0.245):
ffplay udp://10.143.0.246:9998
```
