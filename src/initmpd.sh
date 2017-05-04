#!/bin/sh

find /music/ | grep "\.mp3"  | awk -F "//////"  '{ print( "\"file://"  $1  "\"" )} ' | xargs -n 1 mpc add

find /music/ | grep "\.flac" | awk -F "//////"  '{ print( "\"file://"  $1  "\"" )} ' | xargs -n 1 mpc add

mpc volume `cat /music/volume.mpd`
mpc random on
mpc play


