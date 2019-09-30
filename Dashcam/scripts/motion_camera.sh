#!/bin/sh
#
# (Al) - hmm.tricky@gmail.com

# Script that checks if /dev/video0 or /dev/video1 has been created and
# if so do we need to start running motion.

# Need to add check for thread files(s) in motion.conf

  version="v2-2.46"

  global_rc="/root/scripts/global.rc"
  main_dir="/home/camera"
  main_dir_cam1="/home/camera"
  main_dir_cam2="/home/camera"
  status_dir="$main_dir/logs"
  status_file="status.txt"
  status_out="$status_dir/$status_file"
  usb_main_dir="$main_dir/usb"

  motion_camera1_use_usb="no"
  motion_camera1_dev="/dev/video0"
  motion_camera1_time=600
  motion_camera1_width=512
  motion_camera1_height=288
  motion_camera1_fps=8

  motion_camera2_use_usb="yes"
  motion_camera2_dev=""
  motion_camera2_time=600
  motion_camera2_width=512
  motion_camera2_height=288
  motion_camera2_fps=8

  video_delay=6
  GPS_wait="yes"

  usb_device="/dev/sda1"
  usb_mount="yes"

printf "$$" > /tmp/motion.pid
rm -f /etc/motion/camera1.conf
rm -f /etc/motion/camera2.conf

stop_motion()
{
	kill -15 `cat /var/run/motion/motion.pid`
	printf "`date +%T` [motion_camera]: motion stopped\n" >> $status_out
	printf "motion closed\0" >> /tmp/dash_fifo &

#	if [ "$usb_mount" = "yes" ] && [ ! -z `mount | grep "$usb_device" | awk '{print $1}'` ]; then
#	 umount $usb_device 2>/dev/null
#	fi

	exit
}
	trap 'stop_motion' INT TERM USR1

check_globals()
{
	if [ -f $global_rc ]; then
	 tmp_glob="`grep log_directory $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z $tmp_glob ]; then
	  status_dir="$tmp_glob"
	  status_out="$status_dir/$status_file"
	 fi
	 tmp_glob="`grep motion_enabled $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_enabled="$tmp_glob"; fi
	 tmp_glob="`grep usb_mount $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then usb_mount="$tmp_glob"; fi
	 tmp_glob="`grep usb_directory $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then usb_directory="$tmp_glob"; fi
	 tmp_glob="`grep video_delay $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then video_delay="$tmp_glob"; fi
	 tmp_glob="`grep GPS_wait $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then GPS_wait="$tmp_glob"; fi

	 tmp_glob="`grep motion_camera1_use_usb $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera1_use_usb="$tmp_glob"; fi
	 tmp_glob="`grep motion_camera1_time $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera1_time="$tmp_glob"; fi
	 tmp_glob="`grep motion_camera1_dev $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera1_dev="$tmp_glob"; fi
	 tmp_glob="`grep motion_camera1_fps $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera1_fps="$tmp_glob"; fi
	 tmp_glob="`grep motion_camera1_width $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera1_width="$tmp_glob"; fi
	 tmp_glob="`grep motion_camera1_height $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera1_height="$tmp_glob"; fi

	 tmp_glob="`grep motion_camera2_use_usb $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera2_use_usb="$tmp_glob"; fi
	 tmp_glob="`grep motion_camera2_dev $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ] && [ "$tmp_glob" != "none" ] ; then motion_camera2_dev="$tmp_glob"; fi
	 tmp_glob="`grep motion_camera2_fps $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera2_fps="$tmp_glob"; fi
	 tmp_glob="`grep motion_camera2_width $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera2_width="$tmp_glob"; fi
	 tmp_glob="`grep motion_camera2_height $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera2_height="$tmp_glob"; fi
	 tmp_glob="`grep motion_camera2_time $global_rc | grep -v ^# | awk '{print$2}'`"
	 if [ ! -z "$tmp_glob" ]; then motion_camera2_time="$tmp_glob"; fi
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

	if [ "$motion_enabled" = "no" ]; then
	 printf "`date +%T` [motion_camera]: motion is disabled in $global_rc. Exiting.\n" >> $status_out
	 printf "motion closed\0" >> /tmp/dash_fifo &
	 exit
	fi

	touch "$status_out" > /dev/null 2>&1
	status=$?
	if [ $status -ne 0 ]; then
	 old_status_dir="$status_dir"
	 status_dir="$main_dir/logs"
	 status_out="$status_dir/$status_file"
	 printf "`date +%T` [motion_camera]: * Write failed for $old_status_dir on $usb_device. Using $status_dir *\n" >> $status_out
	fi

	 if [ "$motion_camera1_use_usb" = "yes" ]; then
	  touch "$usb_directory/.test" > /dev/null 2>&1
	  status=$?
	  if [ $status -ne 0 ]; then
	   printf "`date +%T` [motion_camera]: * Write failed for $usb_directory/rear on $usb_device. Using $main_dir/rear *\n" >> $status_out
	  else
	   main_dir_cam1="$usb_directory"
	   mkdir -p "$main_dir_cam1/front" "$main_dir_cam1/rear" "$main_dir_cam1/audio" "$main_dir_cam1/logs/tmp"
	  fi
	 fi
#	else
#	 if [ "$motion_camera1_use_usb" = "yes" ]; then
#	  printf "`date +%T` [motion_camera]: Notice: \"motion_camera1_use_usb\" is $motion_camera1_use_usb, \"usb_mount\" is $usb_mount but storage not mounted\n" >> $status_out
#	 fi

	 if [ "$motion_camera2_use_usb" = "yes" ]; then
	  touch "$usb_directory/.test" > /dev/null 2>&1
	  status=$?
	  if [ $status -ne 0 ]; then
	   printf "`date +%T` [motion_camera]: * Write failed for $usb_directory/rear on $usb_device. Using $main_dir/rear *\n" >> $status_out
	  else
	   main_dir_cam2="$usb_directory"
	   mkdir -p "$main_dir_cam2/front" "$main_dir_cam2/rear" "$main_dir_cam2/audio" "$main_dir_cam2/logs/tmp"
	  fi
	 fi
#	else
#	 if [ "$motion_camera1_use_usb" = "yes" ]; then
#	  printf "`date +%T` [motion_camera]: Notice: \"motion_camera1_use_usb\" is $motion_camera1_use_usb, \"usb_mount\" is $usb_mount but storage not mounted\n" >> $status_out
#	 fi
	fi

	if [ ! -f $status_dir/tmp/event.ct ]; then
	 printf "`date +%T` [motion]: Creating event counter.\n" >> $status_out
	 printf "0" > $status_dir/tmp/event.ct
	fi
	if [ ! -f $status_dir/tmp/motion.ct ]; then
	 printf "`date +%T` [motion]: Creating motion counter.\n" >> $status_out
	 printf "0" > $status_dir/tmp/motion.ct
	fi

        event_count="`cat $status_dir/tmp/event.ct`"
	file_count="`cat $status_dir/tmp/motion.ct`"
	if [ -f /tmp/first_run.tmp ]; then
	 if [ $file_count -eq $event_count ]; then
	  file_count="`expr $file_count + 1`"
	  printf "$file_count" > $status_dir/tmp/event.ct
	 else
	  file_count="`cat $status_dir/tmp/event.ct`"
	 fi
	 printf "$file_count" > $status_dir/tmp/motion.ct
	else
	 event_count="`expr $event_count + 1`"
	 printf "$event_count" > $status_dir/tmp/event.ct
	 touch /tmp/first_run.tmp
	 printf "$event_count" > $status_dir/tmp/motion.ct
	 file_count=$event_count
	fi
        if [ $file_count -lt 10 ];then file_count="0$file_count"; fi

	if [ `date +%Y` -eq "1970" ]; then m_name="$file_count-%%v_motion";
	else m_name="$file_count-%%v_%%Y%%m%%d%%H%%M"; fi

	printf "#\nvideodevice $motion_camera1_dev\n" > /etc/motion/camera1.conf
	printf "#\ntarget_dir $main_dir_cam1/rear\n#\nmovie_filename C1.$m_name\n" >> /etc/motion/camera1.conf
	if [ ! -z "$motion_camera1_time" ]; then printf "#\nmax_movie_time $motion_camera1_time\n" >> /etc/motion/camera1.conf; fi
	if [ ! -z "$motion_camera1_fps" ]; then printf "#\nframerate $motion_camera1_fps\n" >> /etc/motion/camera1.conf; fi
	if [ ! -z "$motion_camera1_width" ]; then printf "#\nwidth $motion_camera1_width\n" >> /etc/motion/camera1.conf; fi
	if [ ! -z "$motion_camera1_height" ]; then printf "#\nheight $motion_camera1_height\n" >> /etc/motion/camera1.conf; fi

	if [ ! -z "$motion_camera2_dev" ]; then
	 printf "#\nvideodevice $motion_camera2_dev\n" > /etc/motion/camera2.conf
	 printf "#\ntarget_dir $main_dir_cam2/rear\n#\nmovie_filename C2.$m_name\n" >> /etc/motion/camera2.conf
	 if [ ! -z "$motion_camera2_time" ]; then printf "#\nmax_movie_time $motion_camera2_time\n" >> /etc/motion/camera2.conf; fi
	 if [ ! -z "$motion_camera2_fps" ]; then printf "#\nframerate $motion_camera2_fps\n" >> /etc/motion/camera2.conf; fi
	 if [ ! -z "$motion_camera2_width" ]; then printf "#\nwidth $motion_camera2_width\n" >> /etc/motion/camera2.conf; fi
	 if [ ! -z "$motion_camera2_height" ]; then printf "#\nheight $motion_camera2_height\n" >> /etc/motion/camera2.conf; fi
	else
	 rm -f /etc/motion/camera2.conf
	fi

	gps_count=0
	if [ "$GPS_wait" = "yes" ] && [ ! -z `pgrep gps_logger` ]; then
	 while [ ! -f /tmp/gps_fix.tmp ]
	  do
	   sleep 1
	   gps_count="`expr $gps_count + 1`"
	   if [ $gps_count -ge 180 ]; then
            printf "`date +%T` [motion_camera]: Timed out waiting for GPS\n" >> $status_out
	    break
	   fi
	  done
	fi

	sleep $video_delay
	while(true)
	 do
###	  if [ ! -c "$motion_camera1_dev" ]; then
#	   printf "`date +%T` [motion_camera]: $motion_camera1_dev not available. Sleeping.\n" >> $status_out
###	   if [ -f /var/run/motion/motion.pid ]; then
###	    kill -SIGINT `cat /var/run/motion/motion.pid`
###	    rm /var/run/motion/motion.pid
###	   fi
###	  else
	   if [ ! -f /var/run/motion/motion.pid ]; then
	    printf "`date +%T` [motion_camera]: Started recording $main_dir_cam1/rear/C1.$file_count-01_`date +%Y%m%d%H%M`\n" >> $status_out
	    if [ ! -z "$motion_camera2_dev" ]; then printf "`date +%T` [motion_camera]: Started recording $main_dir_cam2/rear/C2.$file_count-01_`date +%Y%m%d%H%M`\n" >> $status_out; fi
	    /usr/bin/motion > /dev/null 2>&1 &
 	   else
	    motion_pid="`cat /var/run/motion/motion.pid`"
	    if [ -z "`ps -p $motion_pid | grep motion`" ]; then
	     printf "`date +%T` [motion_camera]: Started recording $main_dir_cam1/rear/C1.$file_count-01_`date +%Y%m%d%H%M`\n" >> $status_out
	     if [ ! -z "$motion_camera2_dev" ]; then printf "`date +%T` [motion_camera]: Started recording $main_dir_cam2/rear/C2.$file_count-01_`date +%Y%m%d%H%M`\n" >> $status_out; fi
	     /usr/bin/motion > /dev/null 2>&1 &
#	    else
#	     printf "`date +%T` [motion_camera]: $motion_camera1_dev found, motion already running.\n" >> $status_out
	    fi
	   fi
###	  fi
	  sleep 12
	 done
exit
