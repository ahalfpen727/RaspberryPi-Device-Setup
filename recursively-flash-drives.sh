#! /bin/bash
#Starter for a script to detect USB SD card readers on laptop and then use dcfldd to write image to multiple cards

echo "Let's see what drives are available"
#Create a variable to store the first part of the directory
dev="/dev/sd"
#For loop to iterate through the drive letters
for drive in b c d e f
do
    #echo $dev$drive
    #Show the drives that are attached using the dev variable and the drive variable created by for loop
    volume=$(df | grep -o $dev$drive)
    echo $volume
    if [ "$volume" = "/dev/sdb" ]
    then
        echo "SDB Found"
    fi
done


#DANGEROUS COMMAND BELOW DON'T RUN IT UNTIL YOU ARE 100% CERTAIN THE DRIVES ARE CORRECT
#dcfldd if=./hackpool.img of=/dev/sdb of=/dev/sdc of=/dev/mmcblk0 sizeprobe=if




