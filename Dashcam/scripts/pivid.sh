#!/bin/sh
#
# (Al) - hmm.tricky@gmail.com

# Looping script which records video from the Pi camera.

version="v2-2.74"
pivid_day_start=06
pivid_day_options="-n -hf -vf -vs -ex antishake"
pivid_night_start=18
pivid_night_options="-n -hf -vf -vs -br 55 -ex night"
pivid_high_res="-w 1920 -h 1080"
pivid_storage_chg=32
pivid_use_usb="yes"
pivid_time=900
video_delay=6

quiet_mode="no"
use_gpio_leds=""
led_2_gpio=1

global_rc="/root/scripts/global.rc"
main_dir="/home/camera"
usb_directory="$main_dir/usb"
status_dir="$main_dir/logs"
status_file="status.txt"
status_out="$status_dir/$status_file"

usb_device="/dev/sda1"
usb_mount="yes"

GPS_wait="yes"

printf "$$" > /tmp/pivid.pid

stop_video()
{
# 	kill -2 `pidof -x raspivid`
 	kill -SIGTERM `pidof -x raspivid` 2>/dev/null
	sync;sync
	if [ -z $use_gpio_leds ]; then /usr/bin/gpio write $led_2_gpio 0; fi
	printf "`date +%T` [pivid]: Stopped recording event $file_count ($seq_count files)\n" >> $status_out
	printf "pivid closed\0" >> /tmp/dash_fifo &
	sync

#	if [ "$usb_mount" = "yes" ] && [ ! -z `mount | grep "$usb_device" | awk '{print $1}'` ]; then
#	 umount $usb_device 2>/dev/null
#	fi

	exit 0
}

check_globals()
{
	if [ -f $global_rc ]; then
	 tmp_glob="`grep log_directory $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then
	  status_dir="$tmp_glob"
	  status_out="$status_dir/$status_file"
	 fi
	 tmp_glob="`grep main_directory $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then main_dir="$tmp_glob"; fi
	 tmp_glob="`grep pivid_day_start $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then pivid_day_start="$tmp_glob"; fi
	 tmp_glob="`grep pivid_night_start $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then pivid_night_start="$tmp_glob"; fi
	 tmp_glob="`grep pivid_day_options $global_rc | grep -v ^# | cut -c 19-80`"
	 if [ ! -z "$tmp_glob" ]; then pivid_day_options="$tmp_glob"; fi
	 tmp_glob="`grep pivid_night_options $global_rc | grep -v ^# | cut -c 21-80`"
	 if [ ! -z "$tmp_glob" ]; then pivid_night_options="$tmp_glob"; fi
	 tmp_glob="`grep pivid_normal_res $global_rc | grep -v ^# | cut -c 18-40`"
	 if [ ! -z "$tmp_glob" ]; then
	  pivid_normal_res="$tmp_glob"
	  res_size="$pivid_normal_res"
	 else
	  res_size="-w 960 -h 540"
	 fi
	 tmp_glob="`grep pivid_high_res $global_rc | grep -v ^# | cut -c 16-40`"
	 if [ ! -z "$tmp_glob" ]; then pivid_high_res="$tmp_glob"; fi
	 tmp_glob="`grep pivid_storage_chg $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then pivid_storage_chg="$tmp_glob"; fi
	 tmp_glob="`grep pivid_time $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then pivid_time="$tmp_glob"; fi
	 tmp_glob="`grep video_delay $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then video_delay="$tmp_glob"; fi
	 tmp_glob="`grep pivid_use_usb $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then pivid_use_usb="$tmp_glob"; fi

	 tmp_glob="`grep use_gpio_leds $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then use_gpio_leds="$tmp_glob"; fi
	 if [ $use_gpio_leds != "no" ]; then use_gpio_leds=""; fi

	 tmp_glob="`grep quiet_mode $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then quiet_mode="$tmp_glob"; fi
	 tmp_glob="`grep led_2_gpio $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then led_2_gpio="$tmp_glob"; fi
	 tmp_glob="`grep GPS_wait $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then GPS_wait="$tmp_glob"; fi

	 tmp_glob="`grep usb_mount $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then usb_mount="$tmp_glob"; fi
	 tmp_glob="`grep usb_directory $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then usb_directory="$tmp_glob"; fi
	fi
}
	check_globals
	mkdir -p "$main_dir/front" "$main_dir/rear" "$main_dir/audio" "$status_dir/tmp"

	tmp_glob="`grep usb_device $global_rc | grep -v ^# | awk '{print$2}'`"
	if [ ! -z "$tmp_glob" ]; then usb_device="$tmp_glob"; fi
	if [ "$usb_mount" = "yes" ] && [ ! -z `mount | grep "$usb_device" | awk '{print $1}'` ]; then
	 global_rc="$usb_directory/global.rc"
	 if [ -f $global_rc ]; then
	  check_globals
	 fi

	 touch "$status_out" > /dev/null 2>&1
	 status=$?
	 if [ $status -ne 0 ]; then
	  old_status_dir="$status_dir"
	  status_dir="$main_dir/logs"
	  status_out="$status_dir/$status_file"
	  printf "`date +%T` [pivid]: * Write failed for $old_status_dir using $status_dir *\n" >> $status_out
	 fi

	 if [ "$pivid_use_usb" = "yes" ]; then
	  touch "$usb_directory/.test" > /dev/null 2>&1
	  status=$?
	  if [ $status -ne 0 ]; then
	   printf "`date +%T` [pivid]: * Write failed for $usb_directory/front on $usb_device. Using $main_dir/front *\n" >> $status_out
#	   umount $usb_device > /dev/null 2>&1
	  else
	   main_dir="$usb_directory"
	   mkdir -p "$main_dir/front" "$main_dir/rear" "$main_dir/audio" "$main_dir/logs/tmp"
          fi
	 fi
#	else
#	 if [ "$pivid_use_usb" = "yes" ]; then
#	  printf "`date +%T` [pivid]: Notice: \"pivid_use_usb\" is $pivid_use_usb, \"usb_mount\" is $usb_mount but storage not mounted\n" >> $status_out
#	 fi
	fi

	disk_size="`df -h $main_dir | grep \/ | awk -F"G" '{print $1}' | awk '{print $2}' | cut -d\. -f1`"
	if [ $disk_size -gt $pivid_storage_chg ]; then
	 res_size="$pivid_high_res"
	fi

	if [ ! -f $status_dir/tmp/event.ct ]; then
	 printf "`date +%T` [pivid]: Creating event counter.\n" >> $status_out
	 printf "0" > $status_dir/tmp/event.ct
	fi
	if [ ! -f $status_dir/tmp/pivid.ct ]; then
	 printf "`date +%T` [pivid]: Creating pivid counter.\n" >> $status_out
	 printf "0" > $status_dir/tmp/pivid.ct
	fi

        event_count="`cat $status_dir/tmp/event.ct`"
	file_count="`cat $status_dir/tmp/pivid.ct`"
	if [ -f /tmp/first_run.tmp ]; then
	 if [ $file_count -eq $event_count ]; then
	  file_count="`expr $file_count + 1`"
	  printf "$file_count" > $status_dir/tmp/event.ct
	 else
	  file_count="`cat $status_dir/tmp/event.ct`"
	 fi
	 printf "$file_count" > $status_dir/tmp/pivid.ct
	else
	 event_count="`expr $event_count + 1`"
	 printf "$event_count" > $status_dir/tmp/event.ct
	 touch /tmp/first_run.tmp
	 printf "$event_count" > $status_dir/tmp/pivid.ct
	 file_count=$event_count
	fi
        if [ $file_count -lt 10 ];then file_count="0$file_count"; fi

	sleep $video_delay
	seq_count=1

	trap 'stop_video' INT TERM USR1

	gps_count=0
	if [ "$GPS_wait" = "yes" ] && [ ! -z `pgrep gps_logger` ]; then
	 while [ ! -f /tmp/gps_fix.tmp ]
	  do
	   sleep 1
	   gps_count="`expr $gps_count + 1`"
	   if [ $gps_count -ge 180 ]; then
	    printf "`date +%T` [pivid]: Timed out waiting for GPS\n" >> $status_out
	    touch /tmp/no_gps_fix.tmp
	    break
	   fi
	  done
	fi

	pivid_time="`expr $pivid_time \* 1000`"

	while(true)
	 do
	  if [ `date +%Y` -eq "1970" ]; then ep_date=TRUE;
	  else ep_date=FALSE; fi

	  if [ $seq_count -lt 10 ];then seq_count="0$seq_count"; fi

	  start_mins="`date +%M`"
	  options="$pivid_day_options"
	  hour="`date +%H`"
	  if [ "$ep_date" = "FALSE" ]; then
	   date_time="`date +%Y%m%d%H%M`"
	   if [ "$hour" -ge "$pivid_night_start" -o "$hour" -lt "$pivid_day_start" ]; then
	    options="$pivid_night_options"
	   fi
	  else
	   date_time="pivid"
	  fi

	  printf "`date +%T` [pivid]: Started recording $main_dir/front/$file_count-""$seq_count""_$date_time\n" >> $status_out
	  printf "`date +%T` [pivid]: Resolution: $res_size  Options: $options  Length: $pivid_time\n" >> $status_out
	   if [ -z $use_gpio_leds ]; then
	    if [ "$quiet_mode" = "yes" ]; then
	     /root/scripts/flash quiet_mode & 
	    else
	     /usr/bin/gpio write $led_2_gpio 1;
	    fi
	   fi

	  /opt/vc/bin/raspivid $res_size -o $main_dir/front/$file_count-""$seq_count""_$date_time.h264 -t $pivid_time $options > /dev/null 2>&1

	  end_mins="`date +%M`"
	  if [ $start_mins -eq $end_mins ]; then
	   printf "`date +%T` [pivid]: Recording time is less than 1 minute. Maybe a problem with the front camera, exiting.\n" >> $status_out
	   if [ -z $use_gpio_leds ]; then
	    /root/scripts/flash $led_2_gpio 20 180 0 -q & /root/scripts/flash $led_1_gpio 16 180 1 -q &>/dev/null
	   fi
	   exit
	  fi
	  seq_count="`expr $seq_count + 1`"
	 done
