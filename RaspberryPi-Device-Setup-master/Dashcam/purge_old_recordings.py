#!/usr/bin/env python

import os
import shutil

ROOT_PATH = os.getenv("ROOT_PATH", "/home/pi")
RECORDINGS_PATH = os.getenv("RECORDINGS_PATH", "recordings")
PERCENTAGE_THRESHOLD = 25.0

statvfs = os.statvfs(ROOT_PATH)

free_bytes = statvfs.f_frsize * statvfs.f_bfree
total_bytes = statvfs.f_frsize * statvfs.f_blocks

free_bytes_percentage = ((1.0 * free_bytes) / total_bytes) * 100

if free_bytes_percentage < PERCENTAGE_THRESHOLD:
    recordings_path = os.path.join(ROOT_PATH, RECORDINGS_PATH)

    recordings = []

    for dir_name in os.listdir(recordings_path):
        recording_path = os.path.join(recordings_path, dir_name)
        recordings.append((recording_path, os.stat(recording_path).st_mtime))

recordings.sort(key=lambda tup: tup[1])
shutil.rmtree(recordings[0][0])
