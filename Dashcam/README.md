Prepping the Operating System

I started the process of building the dashcam by getting the operating system ready for configuration.
Install Raspbian OS on the SD Card

A Raspberry Pi is basically a miniature computer. So, any light-weight operating system would work just fine on it. Since a dashcam is a headless device (no GUI), I opted for a terminal-only version of Raspbian named Raspbian Lite.

The official Raspberry Pi docs do a great job explaining how to install Raspbian Lite on an SD card using a program named Etcher.
Enable WiFi and SSH in Raspbian

In order to download and install third-party tools on the Raspberry Pi, it needs to be connected to the internet. Raspbian can be set up to automatically connect to a wireless network when it boots.

It isn’t necessary, but I wanted to do programming and configuration on Raspberry Pi from my laptop. So, I took the extra time to enable SSH in Raspbian.

I wrote the instructions on enabling WiFi and SSH in Raspbian in another blog post.
Boot the SD Card

Once Raspbian is installed and set up to connect to the internet, the Raspberry Pi is ready to record video! Just put the SD card into the slot and boot it up.
Install ffmpeg in Raspbian

ffmpeg is a command-line utility for converting and streaming video. Since Raspbian Lite is terminal-only, ffmpeg is the best tool for reading video data from the webcam and saving it to the SD card.

It can be installed with:

sudo apt-get install ffmpeg

Programming the Pi to Record Video

With Raspbian Lite and ffmpeg installed, the Pi is ready to be configured to actually record some video.
Create Python Script to Execute ffmpeg

The following script operates the basic video-recording functionality. In summary, the script will:

    Create a folder for recordings, unless it already exists.
	    Create a new folder based on the current time to save video clips.
		    Call ffmpeg from the command-line to take segments of video from the webcam into the new folder.
			
