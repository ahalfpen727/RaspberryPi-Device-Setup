#!/usr/bin/python3
#
# (Al) - hmm.tricky@gmail.com

from __future__ import print_function
from datetime import datetime, timedelta, timezone

import picamera
import datetime as dt

import sys
import signal
import os.path

import socket
import select
import time
import json

import subprocess

__author__ = 'Original GPS code by Moe. Chopped up, stuff added and generally butchered by Al'

GPSD_PORT = 2947
HOST = "127.0.0.1"
PROTOCOL = 'json'
VERSION = "0.27"

previous_speed = 0.2

main_directory = "/home/camera"
usb_directory = main_directory + "/usb"
log_directory = main_directory + "/logs"
logfile_out = log_directory + "/status.txt"

picam_use_usb = "yes"
picam_time = 900
picam_annotate_size = 32
picam_text_background = "None"
picam_width = 1296
picam_height = 730
picam_framerate = 24
picam_quality = 25
video_delay = 6

GPS_device = "/dev/ttyAMA0"
GPS_speed = "km/h"
speed_unit = 3.6
GPS_wait = "yes"
use_LEDs = "yes"
led_2_gpio = 4

picam_split_on = "no"
picam_split_type = "image"
picam_split_width = 640
picam_split_height = 480
picam_split_directory = "/dev/shm"

time.sleep(2)

class GPSDSocket(object):

    def __init__(self, host=HOST, port=GPSD_PORT, gpsd_protocol=PROTOCOL, devicepath=None, verbose=False):

        self.devicepath_alternate = devicepath
        self.response = None
        self.protocol = gpsd_protocol  # What form of data to retrieve from gpsd  TODO: can it handle multiple?
        self.streamSock = None  # Existential
        self.verbose = verbose

# This does not honour a different GPS_device because the globals have not been read yet :(
        if subprocess.call("pgrep gpsd > /dev/null", shell=True):
            junk = "rm -f /var/run/gpsd.sock;/usr/sbin/gpsd -F /var/run/gpsd.sock " + GPS_device
            subprocess.call(junk, shell=True)  

        if host:
            self.connect(host, port)  # No host/port will fail here

    def signal_handler(signal, frame):
        camera.stop_recording()

        if use_LEDs == "yes":
          junk = "/usr/bin/gpio write " + str(led_2_gpio) + " 0"
          subprocess.call(junk, shell=True)

        log_data = dt.datetime.now().strftime('%T [picam]: Stopped recording event ') + str(event_count) + " ({0:02d}".format(int(sequence_count)) + " files)\n"
        log.write(log_data)
        log.close()

        subprocess.call("printf 'picam closed' >> /tmp/dash_fifo &", shell=True)  
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGUSR1, signal_handler)

    #from subprocess import call
    #call(["pkill", "-9", "gpsd"])
    #call(["sleep", "1"])
    #call(["rm", "-f", "/var/run/gpsd.sock"])
    #call(["/usr/sbin/gpsd", "-F", "/var/run/gpsd.sock", "/dev/ttyAMA0"])
    #return_code = subprocess.call("echo Hello World", shell=True)

    def connect(self, host, port):
        """Connect to a host on a given port. """

        for alotta_stuff in socket.getaddrinfo(host, port, 0, socket.SOCK_STREAM):
            family, socktype, proto, _canonname, host_port = alotta_stuff
            try:
                self.streamSock = socket.socket(family, socktype, proto)
                self.streamSock.connect(host_port)
                #self.streamSock.setblocking(False)
                self.streamSock.setblocking(True)

            finally:
               self.watch(gpsd_protocol=self.protocol)

    def watch(self, enable=True, gpsd_protocol='json', devicepath=None):
        command = '?WATCH={{"enable":true,"{0}":true}}'.format(gpsd_protocol)
        if gpsd_protocol == 'human':  # human is the only imitation protocol
            command = command.replace('human', 'json')
        return self.send(command)

    def send(self, commands):
        if sys.version_info[0] < 3:  # Not less than 3, but 'broken hearted' because
            self.streamSock.send(commands)  # 2.7 chokes on 'bytes' and 'encoding='
        else:
            self.streamSock.send(bytes(commands, encoding='utf-8'))  # It craps out here when there is no daemon running

    def __iter__(self):
        return self

    def next(self, timeout=0):
        try:
            (waitin, _waitout, _waiterror) = select.select((self.streamSock,), (), (), timeout)
            if not waitin:
                return
            else:
                gpsd_response = self.streamSock.makefile()  # was '.makefile(buffering=4096)' In strictly Python3
                self.response = gpsd_response.readline()  # When does this fail?

            return self.response  # No, seriously; when does this fail?

        except OSError as error:
            sys.stderr.write('The readline OSError in GPSDSocket.next is this: ', error)
            return  # TODO: means to recover from error, except it is an error of unknown etiology or frequency. Good luck.

    __next__ = next  # Workaround for changes in iterating between Python 2.7 and 3.4

    def close(self):
        if self.streamSock:
            self.watch(enable=False)
            self.streamSock.close()
        self.streamSock = None
        return

class Fix(object):

    def __init__(self):
        """Sets of potential data packages from a device through gpsd, as generator of class attribute dictionaries"""
        version = {"release",
                   "proto_major", "proto_minor",
                   "remote",
                   "rev"}

        tpv = {"alt",
               "climb",
               "device",
               "epc", "epd", "eps", "ept",
               "epv", "epx", "epy",
               "lat", "lon",
               "mode",
               "tag",
               "time",
               "track",
               "speed"}

        sky = {"satellites",
               "gdop", "hdop", "pdop", "tdop",
               "vdop", "xdop", "ydop"}

        gst = {"alt",
               "device",
               "lat", "lon",
               "major", "minor",
               "orient"
               "rms",
               "time"}

        att = {"acc_len", "acc_x", "acc_y", "acc_z",
               "depth",
               "device",
               "dip",
               "gyro_x", "gyro_y",
               "heading",
               "mag_len", "mag_st", "mag_x", "mag_y", "mag_z",
               "pitch", "pitch_st",
               "roll", "roll_st",
               "temperature",
               "time",
               "yaw", "yaw_st"}  # TODO: Check Device flags

        pps = {"device",
               "clock_sec", "clock_nsec",
               "real_sec", "real_nsec"}

        device = {"activated",
                  "bps",
                  "cycle", "mincycle",
                  "driver",
                  "flags",
                  "native",
                  "parity",
                  "path",
                  "stopbits",
                  "subtype"}  # TODO: Check Device flags

        poll = {"active",
                "fixes",
                "skyviews",
                "time"}

        devices = {"devices",
                   "remote"}

        error = {"message"}

        # The thought was a quick repository for stripped down versions, to add/subtract' module data packets'
        packages = {"VERSION": version,
                    "TPV": tpv,
                    "SKY": sky,
                    "ERROR": error}  # "DEVICES": devices, "GST": gst, etc.
        # TODO: Create the full suite of possible JSON objects and a better way for deal with subsets
        for package_name, datalist in packages.items():
            #_emptydict = {key: 'n/a' for (key) in datalist}  # There is a case for using None instead of 'n/a'
            _emptydict = {key: '' for (key) in datalist}  # There is a case for using None instead of 'n/a'
            setattr(self, package_name, _emptydict)
        self.SKY['satellites'] = [{'PRN': 'n/a',
                                   'ss': 'n/a',
                                   'el': 'n/a',
                                   'az': 'n/a',
                                   'used': 'n/a'}]


    def refresh(self, gpsd_data_package):
        try:  # 'class', a reserved word is popped to allow, if desired, 'setattr(package_name, key, a_package[key])'
            fresh_data = json.loads(gpsd_data_package)  # error is named "ERROR" the same as the gpsd data package
            package_name = fresh_data.pop('class', 'ERROR')  # If error, return 'ERROR' except if it happened, it
            package = getattr(self, package_name, package_name)  # should have been too broken to get to this point.
            for key in package.keys():  # Iterate attribute package  TODO: It craps out here when device disappears
                #package[key] = fresh_data.get(key, 'n/a')  # that is, update it, and if key is absent in the socket
                package[key] = fresh_data.get(key, '')  # that is, update it, and if key is absent in the socket
                # response, present --> "key: 'n/a'" instead.'
        except AttributeError:  # 'str' object has no attribute 'keys'  TODO: if returning 'None' is a good idea
             # print("No Data")  # This is frequently indicative of the device falling out of the system
             return None
        except (ValueError, KeyError) as error:  # This should not happen, most likely why it's an exception.  But, it
            sys.stderr.write('There was a Value/KeyError at GPSDSocket.refresh: ', error,
                             '\nThis should never happen.')  # happened once.  But I've no idea aside from it broke.

            return None

    def satellites_used(self):  # Should this be ancillary to this class, or even included?
        total_satellites = 0
        used_satellites = 0
        for satellites in self.SKY['satellites']:
            if satellites['used'] is 'n/a':
                return 0, 0
            used = satellites['used']
            total_satellites += 1
            if used:
                used_satellites += 1

        return total_satellites, used_satellites

    def make_datetime(self):  # Should this be ancillary to this class, or even included?

        timeformat = '%Y-%m-%dT%H:%M:%S.000Z'  # ISO8601
        if 'n/a' not in self.TPV['time']:
            gps_datetime_object = datetime.strptime(self.TPV['time'], timeformat).replace(
                tzinfo=(timezone(timedelta(0))))
        else:  # shouldn't break anything, but return wrong Time, when IT, PO, ES, and PT switch to gregorian calendar
            gps_datetime_object = datetime.strptime('1582-10-04T12:00:00.000Z', timeformat).replace(
                tzinfo=(timezone(timedelta(0))))
        return gps_datetime_object

if __name__ == '__main__':

    import argparse

    parser = argparse.ArgumentParser()  # TODO: beautify and idiot-proof makeover to prevent clash from options error
    # Defaults from the command line
    parser.add_argument('-human', dest='gpsd_protocol', const='human', action='store_const', default='human', help='DEFAULT Human Friendlier ')
    # parser.add_argument('-host', action='store', dest='host', default='127.0.0.1', help='DEFAULT "127.0.0.1"')
    # parser.add_argument('-port', action='store', dest='port', default='2947', help='DEFAULT 2947', type=int)
    # parser.add_argument("-verbose", action="store_true", default=False, help="increases verbosity, but not that much")
    # Alternate devicepath
    # parser.add_argument('-device', dest='devicepath', action='store', help='alternate devicepath e.g.,"/dev/ttyUSB4"')
    parser.add_argument('-json', dest='gpsd_protocol', const='json', action='store_const', help='/* output as JSON objects */')

    args = parser.parse_args()
    # session = GPSDSocket(args.host, args.port, args.gpsd_protocol, args.devicepath,
    #                      args.verbose)  # the historical 'session'
    session = GPSDSocket('127.00.1','2947', 'human', 'None', 'False')

    fix = Fix()

def read_globals(global_file):

    global main_directory, log_directory, logfile_out, usb_directory, picam_time, picam_annotate_size
    global picam_text_background, picam_width, picam_height, picam_framerate, picam_use_usb
    global GPS_wait, use_LEDs, led_2_gpio, video_delay, speed_unit, GPS_speed
    global picam_split_on, picam_split_type, picam_split_width, picam_split_height, picam_split_directory

    if(os.path.exists(global_file)):
      with open(global_file, "r") as f:
        for line in f:
          blah = line.split('\t')
          if str(line[0]) != "#":
            if line.find("main_directory")>=0:
                main_directory = "{0[2]}".format(blah)
            elif line.find("log_directory")>=0:
                log_directory = "{0[2]}".format(blah)
                logfile_out = log_directory + "/status.txt"
            elif line.find("usb_directory")>=0:
                usb_directory = "{0[2]}".format(blah)
            elif line.find("picam_time")>=0:
                picam_time = int("{0[2]}".format(blah))
            elif line.find("picam_annotate_size")>=0:
                picam_annotate_size = int("{0[1]}".format(blah))
            elif line.find("picam_text_background")>=0:
                picam_text_background = "{0[1]}".format(blah)
                if picam_text_background == "none":
                    picam_text_background = "None"
            elif line.find("picam_width")>=0:
                picam_width = int("{0[2]}".format(blah))
            elif line.find("picam_use_usb")>=0:
                picam_use_usb = "{0[2]}".format(blah)
            elif line.find("picam_height")>=0:
                picam_height = int("{0[2]}".format(blah))
            elif line.find("picam_framerate")>=0:
                picam_framerate = int("{0[2]}".format(blah))
            elif line.find("picam_quality")>=0:
                picam_quality = int("{0[2]}".format(blah))
            elif line.find("GPS_wait")>=0:
                GPS_wait = "{0[2]}".format(blah)
            elif line.find("use_gpio_leds")>=0:
                use_LEDs = "{0[2]}".format(blah)
            elif line.find("led_2_gpio")>=0:
                led_2_gpio = int("{0[2]}".format(blah))
            elif line.find("video_delay")>=0:
                video_delay = int("{0[2]}".format(blah))
            elif line.find("GPS_device")>=0:
                GPS_device = "{0[2]}".format(blah)
            elif line.find("GPS_speed")>=0:
                GPS_speed = "{0[2]}".format(blah)
                if GPS_speed == "mp/h":
                    speed_unit = 2.2369363
            elif line.find("picam_split_on")>=0:
                picam_split_on = "{0[2]}".format(blah)
            elif line.find("picam_split_type")>=0:
                picam_split_type = "{0[1]}".format(blah)
            elif line.find("picam_split_width")>=0:
                picam_split_width = int("{0[1]}".format(blah))
            elif line.find("picam_split_height")>=0:
                picam_split_height = int("{0[1]}".format(blah))
            elif line.find("picam_split_directory")>=0:
                picam_split_directory = "{0[1]}".format(blah)
      f.close()

    if picam_use_usb == "yes":
       main_directory = usb_directory

    #print(f.readline())


def gps_annotate():

        #time.sleep(0.1)  # to keep from spinning silly, or set GPSDSocket.streamSock.setblocking(False) to True
        for socket_response in session:
            if socket_response and args.gpsd_protocol is 'human':  # Output for humans because it's the command line.
               fix.refresh(socket_response)

               speed_ms = '{speed:0<5}'.format(**fix.TPV)

               if speed_ms in ['00000']:
                current_speed = "0.0"
               else:
                speed_cv = float(speed_ms)
                current_speed = speed_cv * speed_unit
                global previous_speed
                previous_speed = current_speed
            else:
             current_speed = previous_speed # previous is better than none

            lat_float = "{lat:0<11}".format(**fix.TPV)
            lon_float = "{lon:0<12}".format(**fix.TPV)

            gps_text = dt.datetime.now().strftime('%d/%m/%Y %H:%M:%S ') + "Lat: {0:2.6f} ".format(float(lat_float)) + "Long: {0:2.6f} ".format(float(lon_float)) + "Sp: {0:3.0f} ".format(float(current_speed)) + GPS_speed + " Sats: {0[1]:2d} / {0[0]:2d}".format(fix.satellites_used())
            break

        return gps_text


def event_number():

    with open(log_directory + "/tmp/event.ct", "r") as f:
        event_count = int(f.read())
    f.close()
    if(os.path.exists(log_directory + "/tmp/picam.ct")):
      with open(log_directory + "/tmp/picam.ct", "r") as f:
          file_count = int(f.read())
      f.close()
    else:
      with open(log_directory + "/tmp/picam.ct", "w") as f:
          f.write("0")
          file_count = 0
      f.close()
    if(os.path.exists("/tmp/first_run.tmp")):
      if file_count == event_count:
        file_count += 1
        with open(log_directory + "/tmp/event.ct", "w") as f:
          f.write(str(file_count))
        f.close()
      else:
        with open(log_directory + "/tmp/event.ct", "r") as f:
          file_count = int(f.read())
        f.close()
      with open(log_directory + "/tmp/picam.ct", "w") as f:
        f.write(str(file_count))
      f.close()
    else:
     event_count += 1
     with open(log_directory + "/tmp/event.ct", "w") as f:
       f.write(str(event_count))
     f.close()
     open("/tmp/first_run.tmp", 'a').close()
     with open(log_directory + "/tmp/picam.ct", "w") as f:
       f.write(str(event_count))
     f.close()
     file_count = event_count
    return file_count

read_globals("/root/scripts/global.rc")
if picam_use_usb == "yes":
  if(os.path.exists(usb_directory + "/global.rc")):
    global_file = usb_directory + "/global.rc"
    read_globals(global_file)

log = open(logfile_out, "a", 1) #non blocking

gps_count = 0
if GPS_wait == "yes":
    while (os.path.exists("/tmp/gps_fix.tmp") == False):
        time.sleep(1.0)
        gps_count += 1
        if gps_count >= 180:
            log_data = dt.datetime.now().strftime('%T [picam]: ') + "Timed out waiting for GPS\n"
            log.write(log_data)
            subprocess.call("touch /tmp/no_gps_fix.txt", shell=True)
            break

time.sleep(video_delay)

with picamera.PiCamera() as camera:

    event_count = event_number()

    camera.resolution = (picam_width, picam_height)
    camera.framerate = picam_framerate
    camera.vflip = True
    camera.hflip = True
    camera.annotate_text_size = picam_annotate_size

    if picam_text_background == "None":
        camera.annotate_background = "None"
    else:
        camera.annotate_background = picamera.Color(picam_text_background)
    camera.annotate_foreground = picamera.Color(y=1.0, u=0, v=0)

#    camera.annotate_frame_num = True

    camera.awb_mode = 'horizon'

    if use_LEDs == "yes":
      junk = "/usr/bin/gpio mode " + str(led_2_gpio) + " out"
      subprocess.call(junk, shell=True)  
      junk = "/usr/bin/gpio write " + str(led_2_gpio) + " 1"
      subprocess.call(junk, shell=True)  

    picam_split_video = picam_split_directory + "/video.h264"
    picam_split_image = picam_split_directory + "/image.jpg"

    sequence_count = 1
    while True:
#      video_file = main_directory + dt.datetime.now().strftime('/front/%Y%m%d%H%M_') + "{0:02d}_{1:02d}.h264".format(event_count, sequence_count)
      video_file = main_directory + "/front/" + "{0:02d}-{1:02d}_".format(event_count, sequence_count) + dt.datetime.now().strftime('%Y%m%d%H%M.h264')

      log_data = dt.datetime.now().strftime('%T [picam]: ') + "Started recording " + video_file + "\n"
      log.write(log_data)

      camera.start_recording(video_file, quality=picam_quality) # 1 - 40

      if (picam_split_on == "yes") and ((picam_split_type == "video") or (picam_split_type == "both")):
        camera.start_recording(picam_split_video, splitter_port=2, resize=(picam_split_width, picam_split_height))

      start = dt.datetime.now()
      while (dt.datetime.now() - start).seconds < picam_time:

        camera.annotate_text = gps_annotate()
        camera.wait_recording(0.2)
        if (picam_split_on == "yes") and ((picam_split_type == "image") or (picam_split_type == "both")):
          camera.capture(picam_split_image, use_video_port=True, resize=(picam_split_width, picam_split_height))

      if (picam_split_on == "yes") and ((picam_split_type == "video") or (picam_split_type == "both")):
        camera.stop_recording(splitter_port=2)
      camera.stop_recording()

      sequence_count += 1

    sys.exit(0)
