#!/bin/sh
#
# (Al) - hmm.tricky@gmail.com

# Dashcam start up program

  version="2-1.4"

  global_rc="/root/scripts/global.rc"
  main_dir="/home/camera"
  log_dir="$main_dir/logs"
  status_file="status.txt"
  status_out="$log_dir/$status_file"

  usb_device="/dev/sda1"
  usb_directory="$main_dir/usb"

  status_append_log="no"
  status_logs=5

  GPS_enabled="yes"
  GPS_wait="yes"
  pi_camera_method="pivid"
  picam_enabled="no"
  motion_enabled="yes"
  audio_enabled="no"
  pico_enabled="no"
  button_enabled="yes"

  high_temp="81000"
  low_temp="77000"
  over_temp="84000"

  led_2_gpio=4
  use_gpio_leds="yes"

  pivid_use_usb="yes"
  motion_camera1_use_usb="no"
  audio_use_usb="no"

  root_limit=95
  usb_limit=95
  using_usb=""
  storage_mounted=""
  samba_enabled=""

  tmp_stat="/tmp/stat.txt"
  rm -f /tmp/*.pid /tmp/gps_fix.tmp
  first_run=true

time_to_die()
{
	printf "Stopping...\n"
	if [ "$motion_enabled" = "yes" ]; then
	 pkill --signal SIGTERM motion
	 sleep 1
	fi
	if [ "$pi_camera_method" = "pivid" ]; then
	 pkill --signal SIGTERM pivid
	 sleep 1
	elif [ "$pi_camera_method" = "picam" ]; then
	 pkill --signal SIGTERM -f picam.py
	 sleep 1
	fi
	if [ "$audio_enabled" = "yes" ]; then
	 kill -15 `cat /tmp/audio.pid` > /dev/null 2>&1
	 pkill --signal SIGINT arecord
	 sleep 1
	fi
	if [ "$GPS_enabled" = "yes" ]; then
	 pkill --signal SIGTERM gps_logger
	 sleep 1
	fi
	if [ "$pico_enabled" = "yes" ]; then
	 pkill --signal SIGTERM -f pico.sh
	 sleep 1
	fi
	printf "`date +%T` [dashcam]: Stopped.\n" >> $status_out
exit
}

check_usb()
{
	usb_mount="`grep usb_mount $global_rc | grep -v ^# | awk '{print$2}'`"
	if [ "$usb_mount" != "yes" ]; then
	 printf "`date +%T` [dashcam]: USB mount disabled in $global_rc\n" >> $tmp_stat
	 return
	fi

	tmp_glob="`grep usb_device $global_rc | grep -v ^# | awk '{print$2}'`"
	if [ ! -z "$tmp_glob" ]; then usb_device="$tmp_glob"; fi

	if [ -z "`mount | grep $usb_device`" ]; then
	 if [ -b "$usb_device" ]; then
#	  if [ ! -d "$usb_directory" ]; then
	   mkdir -p "$usb_directory/front" "$usb_directory/rear" "$usb_directory/audio" "$log_dir/tmp" > /dev/null 2>&1
#	  fi
	  mount $usb_device $usb_directory > /dev/null 2>&1
	  status=$?
	  if [ $status -ne 0 ]; then
	   printf "`date +%T` [dashcam]: Failed to mount USB device $usb_device on $usb_directory\n" >> $tmp_stat
	   return
	  else
	   printf "`date +%T` [dashcam]: Mounted $usb_device on $usb_directory\n" >> $tmp_stat
	   df > /dev/null
	   storage_mounted="True"
	  fi
	 else printf "`date +%T` [dashcam]: $usb_device is not available\n" >> $tmp_stat
	 fi
	else
	 printf "`date +%T` [dashcam]: $usb_device already mounted on $usb_directory\n" >> $tmp_stat
         storage_mounted="True"
	fi
	mkdir -p "$usb_directory/front" "$usb_directory/rear" "$usb_directory/audio" "$usb_directory/logs/tmp" > /dev/null 2>&1

	touch "$usb_directory/logs/tmp/.test" > /dev/null 2>&1
	status=$?
	if [ $status -ne 0 ]; then
	 printf "`date +%T` [dashcam]: * Write failed for $usb_directory/logs on $usb_device. Using $main_dir/logs *\n" >> $tmp_stat
#	 umount $usb_device > /dev/null 2>&1
         storage_mounted=""
	 usb_directory="$main_dir"
	 log_dir="$main_dir/logs"
	 status_out="$log_dir/$status_file"
	fi
}

check_globals()
{
	if [ -f $global_rc ]; then
	 tmp_glob="`grep main_directory $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then main_dir="$tmp_glob"; fi
	 tmp_glob="`grep log_directory $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then
	  log_dir="$tmp_glob"
	  status_out="$log_dir/$status_file"
	 fi
	 tmp_glob="`grep usb_directory $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then usb_directory="$tmp_glob"; fi

	 tmp_glob="`grep status_append_log $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then status_append_log="$tmp_glob"; fi
	 tmp_glob="`grep status_logs $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then status_logs="$tmp_glob"; fi

	 tmp_glob="`grep GPS_enabled $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then GPS_enabled="$tmp_glob"; fi
	 tmp_glob="`grep GPS_wait $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then GPS_wait="$tmp_glob"; fi
	 tmp_glob="`grep pi_camera_method $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then pi_camera_method="$tmp_glob"; fi

	 tmp_glob="`grep camera_method $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ "$tmp_glob" = "picam" ]; then picam_enabled="yes"; fi

	 tmp_glob="`grep motion_enabled $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_enabled="$tmp_glob"; fi
	 tmp_glob="`grep audio_enabled $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then audio_enabled="$tmp_glob"; fi
	 tmp_glob="`grep pico_enabled $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then pico_enabled="$tmp_glob"; fi

	 tmp_glob="`grep pivid_use_usb $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then pivid_use_usb="$tmp_glob"; fi
	 tmp_glob="`grep motion_camera1_use_usb $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera1__use_usb="$tmp_glob"; fi
	 tmp_glob="`grep audio_use_usb $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then audio_use_usb="$tmp_glob"; fi

	 tmp_glob="`grep use_gpio_leds $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then use_gpio_leds="$tmp_glob"; fi
	 tmp_glob="`grep led_2_gpio $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then led_2_gpio="$tmp_glob"; fi

	 tmp_glob="`grep high_temp $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then high_temp="$tmp_glob""000"; fi
	 tmp_glob="`grep low_temp $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then low_temp="$tmp_glob""000"; fi
	 tmp_glob="`grep over_temp $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then over_temp="$tmp_glob""000"; fi

	 tmp_glob="`grep samba_enabled $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then samba_enabled="$tmp_glob"; fi
	fi
}

rotate_logs()
{
	printf "`date +%T` [dashcam]: Rotating status.txt log files\n" >> $tmp_stat
 	stat_tot="`ls $log_dir/status.*.txt 2>/dev/null | tail -1 | awk -F\. '{print $2}'`"
	if [ ! -z "$stat_tot" ]; then
	 if [ "`expr $stat_tot + 1`" -gt "$status_logs" ]; then
	  stat_tot="`expr $status_logs - 1`"
	 fi
	 mv_count="`expr $stat_tot + 1`"

	 while [ "$stat_tot" -gt 0 ]
	  do
	   if [ -f $log_dir/status.$stat_tot.txt ]; then
	    mv $log_dir/status.$stat_tot.txt $log_dir/status.$mv_count.txt
	   fi
	   stat_tot="`expr $stat_tot - 1`"
	   mv_count="`expr $stat_tot + 1`"
	  done
	fi

	mv $status_out $log_dir/status.1.txt > /dev/null 2>&1
	for name in `ls $log_dir/status.*.txt 2>/dev/null`
	 do
	  number="`printf $name | awk -F\. '{print $2}'`"
	  if [ $number -gt $status_logs ]; then
	   printf "`date +%T` [dashcam]: Removing logfile $name\n" >> $tmp_stat
	   rm $name
	  fi
	 done
}

start_samba()
{
	if [ -f /etc/samba/smb.conf ]; then
	 if [ ! -z "`pgrep smbd`" ] || [ ! -z "`pgrep nmbd`" ]; then
	  pkill --signal SIGINT smbd ; pkill --signal SIGINT nmbd
	  sleep 1 
	 fi
	 printf "`date +%T` [dashcam-samba]: Starting nmbd and smbd\n" >> $status_out
	 nmbd -D ; smbd -D
	else
	 printf "`date +%T` [dashcam-samba]: smb.conf file not found\n" >> $status_out
	fi
}
	 
cleanup()
{
limit=$root_limit
all_finished=""
partition="$main_dir"

	while [ -z $all_finished ]
	 do
	  run_cleanup=""
	  f_search="h264"
	  count=0
	  video_dir="$partition/front"
	  used="`df -h $partition | grep \/ | cut -d\% -f1 | awk '{print $5}'`"
	  if [ $used -ge $limit ]; then
	   printf "`date +%T` [dashcam]: $partition is over $limit%% threshold.\n" >> $status_out
	   while [ -z $run_cleanup ]
	    do
             file_count="`ls -l $video_dir | grep $f_search | wc -l`"
	     if [ $file_count -gt 2 ]; then
	      del_file="`ls -t $video_dir | grep $f_search | tail -1`"
	      printf "`date +%T` [dashcam]: Deleting $video_dir/$del_file\n" >> $status_out
	      rm -f $video_dir/$del_file
#	     else
#	      printf "`date +%T` [dashcam]: Nothing available to delete from $video_dir\n" >> $status_out
	     fi
	     count="`expr $count + 1`"
	     if [ $count -eq 2 ]; then
	      f_search="avi"
	      video_dir="$partition/rear"
	     elif [ $count -eq 4 ]; then
	      f_search="wav"
	      video_dir="$partition/audio"
	     elif [ $count -eq 6 ]; then
	      if [ $partition = $usb_directory ] || [ -z $using_usb ]; then all_finished="true"; fi
	      partition="$usb_directory"
	      limit=$usb_limit
	      run_cleanup="false"
	     fi
	    done
	  else
	   if [ $partition = $usb_directory ] || [ -z $using_usb ]; then all_finished="true"; fi
	   partition="$usb_directory"
	   limit=$usb_limit
	  fi
	done
}

	trap 'time_to_die' INT TERM USR1

	rm -f /tmp/dash_fifo
	printf "`date +%T` [dashcam]: (v$version) Starting up...\n" > $tmp_stat

	check_globals
	check_usb

	if [ "$storage_mounted" = "True" ]; then
	 global_rc="$usb_directory/global.rc"
	 if [ -f $global_rc ]; then
 	  printf "`date +%T` [dashcam]: Found $usb_directory/global.rc\n" >> $tmp_stat
	  check_globals
	 fi
	fi
	mkdir -p "$main_dir/front" "$main_dir/rear" "$main_dir/audio" "$log_dir/tmp"

	if [ "$status_append_log" = "no" ]; then rotate_logs; fi
	cat $tmp_stat >> "$status_out"

	if [ -d /home/camera/usb/scripts ]; then
	 cp -u /root/scripts/global.rc /root/scripts/global.rc.org
	 mv /home/camera/usb/scripts/* /root/scripts/
	 rmdir /home/camera/usb/scripts
	 printf "`date +%T` [dashcam]: *** Copied new scripts ***\n" >> $status_out
	 sync;shutdown -r now
	 exit
	fi

	mkfifo -m 0666 /tmp/dash_fifo > /dev/null 2>&1

	if [ $# != 0 ]; then
	 if [ "$1" = "-h" ] || [ "$1" = "--h" ] || [ "$1" = "-help" ] || [ "$1" = "--help" ]; then
	  printf "[4mVersion: $version[0m\n"
	  printf "\nUsage $0 {arguments}\nArguments can be one or more of the following :-\n"
	  printf "pwr_butt | gps_logger | [ pivid | picam ] | motion | audio | pico\n\n"
	  printf "E.G. To start with the button, Pi camera (using pivid) and the USB camera enabled\n[1m$0 pwr_butt pivid motion[m\n\n"
	  printf "Current defaults: motion:$motion_enabled - gps_logger:$GPS_enabled - Pi camera:$pi_camera_method - pwr_butt:$button_enabled - audio:$audio_enabled - pico:$pico_enabled\n\n"
	  exit
	 fi
	 GPS_enabled="no";pi_camera_method="off";motion_enabled="no";audio_enabled="no";button_enabled="no";pico_enabled="no"
	 for args in "$@"
	  do
	   if [ "$args" = "pwr_butt" ]; then button_enabled="yes";
	    elif [ "$args" = "gps_logger" ]; then GPS_enabled="yes";
	    elif [ "$args" = "pivid" ]; then pi_camera_method="pivid";
	    elif [ "$args" = "picam" ]; then pi_camera_method="picam";
	    elif [ "$args" = "motion" ]; then motion_enabled="yes";
	    elif [ "$args" = "audio" ]; then audio_enabled="yes";
	    elif [ "$args" = "pico" ]; then pico_enabled="yes";
	   fi
	  done
	fi

	printf "`date +%T` [dashcam]: motion:$motion_enabled - GPS:$GPS_enabled - Pi camera:$pi_camera_method - power:$button_enabled - audio:$audio_enabled - pico:$pico_enabled\n" >> $status_out

	if [ "$GPS_enabled" = "yes" ]; then
	 if [ ! -z "`pgrep gps_logger`" ]; then
	  printf "`date +%T` [dashcam]: gps_logger is already running\n" >> $status_out
	 else 
	  if [ "$GPS_enabled" != "no" ]; then
	   printf "`date +%T` [dashcam]: Starting gps_logger\n" >> $status_out
	   /root/scripts/gps_logger > /dev/null 2>&1 &
	  fi
	 fi
	fi

	if [ "$button_enabled" = "yes" ]; then
	 if [ ! -z "`pgrep pwr_butt`" ]; then
	  printf "`date +%T` [dashcam]: pwr_butt is already running\n" >> $status_out
	 else 
	  printf "`date +%T` [dashcam]: Starting pwr_butt\n" >> $status_out
	  /root/scripts/pwr_butt > /dev/null 2>&1 &
	 fi
	fi

	if [ "$pico_enabled" = "yes" ]; then
	 printf "`date +%T` [dashcam]: Starting pico\n" >> $status_out
	 /root/scripts/pico.sh > /dev/null 2>&1 &
	fi

	if [ "$audio_enabled" = "yes" ]; then
	 if [ ! -z "`pgrep audio`" ]; then
	  printf "`date +%T` [dashcam]: audio is already running\n" >> $status_out
	 else 
	  printf "`date +%T` [dashcam]: Starting audio\n" >> $status_out
	  /root/scripts/audio.sh > /dev/null 2>&1 &
	 fi
	fi

	if [ "$pi_camera_method" = "pivid" ]; then
	 if [ ! -z "`pgrep pivid`" ]; then
	  printf "`date +%T` [dashcam]: pivid is already running\n" >> $status_out
	 else 
	  printf "`date +%T` [dashcam]: Starting pivid\n" >> $status_out
	  /root/scripts/pivid.sh > /dev/null 2>&1 &
	 fi
	elif [ "$pi_camera_method" = "picam" ]; then
	 if [ ! -z "`pgrep -f picam.py`" ]; then
	  printf "`date +%T` [dashcam]: picam is already running\n" >> $status_out
	 else 
	  printf "`date +%T` [dashcam]: Starting picam\n" >> $status_out
	  /root/scripts/picam.py > /dev/null 2>&1 &
	 fi
	fi

	if [ "$motion_enabled" = "yes" ]; then
	 if [ ! -z "`pgrep motion_camera`" ]; then
	  printf "`date +%T` [dashcam]: motion_camera is already running\n" >> $status_out
	 else 
	  printf "`date +%T` [dashcam]: Starting motion_camera\n" >> $status_out
	  /root/scripts/motion_camera.sh > /dev/null 2>&1 &
	 fi
	fi

	 if [ "$pivid_use_usb" = "yes" ] || [ "$motion_camera1_use_usb" = "yes" ] || [ "$audio_use_usb" = "yes" ] & [ "$storage_mounted" = "True" ]; then
	  using_usb="True"
	 fi

	if [ -z $using_usb ]; then
	 printf "`date +%T` [dashcam]: Disk space threshold is set to $root_limit%%\n" >> $status_out
	else
	 printf "`date +%T` [dashcam]: Disk space threshold is set to $root_limit%% for $main_dir and $usb_limit%% for $main_dir/usb\n" >> $status_out
	fi

	rm -f /tmp/temp.tmp
	sleep 8

	if [ ! -z `which smbd` ] && [ "$samba_enabled" = "yes" ]; then
	 start_samba
	fi

	while (true)
	 do
	  temp="`/opt/vc/bin/vcgencmd measure_temp | awk -F\= '{print $2}'`"
	  therm_temp="`cat /sys/class/thermal/thermal_zone0/temp`"
	  current_speed="`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq`"
	  printf "`date +%T` [dashcam]:`uptime | cut -c10-80`, `expr $current_speed / 1000`Mhz, $temp ($therm_temp)\n" >> $status_out

	  if [ $therm_temp -ge $over_temp ]; then
	   printf "`date +%T` [dashcam]: *** Temperature critical! Shutting down now... ***\n" >> $status_out
	   pkill --signal SIGUSR1 pwr_butt
	   sleep 15;shutdown -h -P now
	   exit
	  fi

	  if [ $therm_temp -ge $high_temp ]; then
	   if [ ! -f /tmp/temp.tmp ]; then
	    printf "`date +%T` [dashcam]: * Temperature over limit, stopping motion... *\n" >> $status_out
	    pkill --signal SIGKILL motion ; sleep 1 ; pkill --signal SIGKILL motion
	    touch /tmp/temp.tmp
	    if [ "$use_gpio_leds" != "no" ]; then
	     /root/scripts/flash $led_2_gpio 50 60 1 -q &
	    fi
	   fi
	  else
	   if [ -f /tmp/temp.tmp ] && [ "$therm_temp" -le "$low_temp" ]; then
	    printf "`date +%T` [dashcam]: Temperature under limit, starting motion...\n" >> $status_out
	    /root/scripts/motion_camera.sh &
	    rm /tmp/temp.tmp
	    if [ "$use_gpio_leds" != "no" ]; then
	     /root/scripts/flash $led_2_gpio 12 300 1 -q &
	    fi
	   fi
	  fi

# Is the Pi camera running as expected?
	  if [ "$first_run" = "false" ]; then
	   if [ "$GPS_wait" = "no" -o -f /tmp/no_gps_fix.tmp ] || [ "$GPS_wait" = "yes" -a -f /tmp/gps_fix.tmp ]; then
	    mmal_procs=`/opt/vc/bin/mmal_vc_diag mmal-stats | wc -l`
	    if [ $mmal_procs -lt 2 ]; then
	     if [ "$use_gpio_leds" != "no" ]; then
	      /root/scripts/flash $led_2_gpio 10 100 0 -q &
	     fi
	     printf "`date +%T` [dashcam]: Pi camera does not seem to be working, restarting $pi_camera_method\n" >> $status_out
	     if [ "$pi_camera_method" = "picam" ]; then
	      pkill --signal SIGTERM -f picam.py
	      /root/scripts/picam.py > /dev/null 2>&1 &
	     elif [ "$pi_camera_method" = "pivid" ]; then
	      pkill --signal SIGTERM pivid
	      /root/scripts/pivid.sh > /dev/null 2>&1 &
	     fi
	    fi
	   fi
	  fi

	  cleanup

	  disk_usage="`df -h $main_dir | grep root | awk '{print $5}'`"
	  if [ ! -z "$using_usb" ]; then
	   usb_usage="`df -h $usb_directory | grep usb | awk '{print $5}'`"
	   printf "`date +%T` [dashcam]: Capacity of $main_dir is $disk_usage%, $usb_directory is $usb_usage%\n" >> $status_out
	  else
	   printf "`date +%T` [dashcam]: Capacity of $main_dir is $disk_usage%\n" >> $status_out
	  fi
	  sleep 60
	  first_run="false"
	 done
exit
