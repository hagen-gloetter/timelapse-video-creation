#! /bin/bash

# Hagen@gloetter.de 2020 
# ideas taken from
# http://trac.ffmpeg.org/wiki/Create%20a%20video%20slideshow%20from%20images
# http://hamelot.io/visualization/using-ffmpeg-to-convert-a-set-of-images-into-a-video/
# http://spielwiese.la-evento.com/hokuspokus/


shopt -s nullglob
_self="${0##*/}"
echo "$_self is called"

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename "$0") [foldername] [soundfile] "
    exit 1
fi
DIR_SRCIMG="$1"
DIR_MP4="h265"
Sound=""

if [[ $# -eq 2 ]]; then
    FN_SOUND="$2"
    echo "Soundfile used: $FN_SOUND"
    Sound=" -i \"$FN_SOUND\" -shortest " # -shortest = Finish encoding when the shortest input stream ends.
fi

FFMPEG=$(which ffmpeg)
if [ $? -eq 0 ]; then
    echo "ffmpeg found"
else
    echo "ffmpeg NOT found"
    exit 1
fi


OutFile=$DIR_SRCIMG/$DIR_MP4/"ffmpeg-timeleape"$(date +"-%Y-%m-%d--%H-%M")".mp4"
#Sound=$baseDir"/nop/SoundCloud-SHAPING_LIGHTS.v2.mp3"

# Functions

function check_DIR {
    DIR=$1
    if [ ! -d "$DIR" ]; then
        echo "Error: Directory ${DIR} not found --> EXIT."
        exit 1
    fi
}
# functions
function check_and_create_DIR {
    DIR=$1
    #  [ -d "$DIR" ] && echo "Directory $DIR exists. -> OK" || mkdir $DIR # works but not so verbose
    if [ -d "$DIR" ]; then
        echo "${DIR} exists -> OK"
    else
        mkdir "$DIR"
        echo "Info: ${DIR} not found. Creating."
    fi
    # check if it worked
    if [ ! -d "$DIR" ]; then
        echo "Error: ${DIR} CAN NOT CREATE --> EXIT."
        exit 1
    fi
}

check_DIR "$DIR_SRCIMG"
cd "$DIR_SRCIMG" || exit 1
check_and_create_DIR "$DIR_MP4"

echo "-----------------------------------------"
echo "Processing Dir:"
pwd
echo "baseDir=$baseDir"
echo "DIR_SRCIMG=$DIR_SRCIMG"
echo "OutFile=$OutFile"
echo "Sound=$Sound"
echo "-----------------------------------------"

# a lot of tests ;-) TO be removed
#echo "find_and_get_timerange_symlink"
#$baseDir/scripts/find_and_get_timerange_symlink.sh 2> find_and_get_timerange_symlink.log
#echo "find_blanks"
#$baseDir/find_blanks.sh 2> find_blanks.log

#ffmpeg -r 30 -i $Sound  -pattern_type glob -i '*.jpg' -c:v libx264 -acodec copy -s 1280x720 $OutFile
#ffmpeg -framerate 30 -pattern_type glob -i '*.jpg' -c:v libx264 -i $Sound -acodec copy -s 1280x720 $OutFile
#GLOB="$DIR_SRCIMG/\*.jpg"
#CMD="ffmpeg -thread_queue_size 512 -framerate 30 -pattern_type glob -i \"$DIR_SRCIMG/*.jpg\" -i $Sound -c:v libx264 -acodec copy -s 1280x720 $OutFile"
# deshake  http://adaptivesamples.com/2014/05/30/camera-stabilisation-with-ffmpeg/
# -vf deshake
#CMD="ffmpeg -thread_queue_size 512 -framerate 30 -pattern_type glob -i \"$DIR_SRCIMG/*.jpg\" -i $Sound -vf deshake -c:v libx264 -acodec copy -flags global_header -pix_fmt yuv420p -s 1280x720  $OutFile"

# -- working ones with sound
#CMD="ffmpeg -thread_queue_size 1024 -framerate 30 -pattern_type glob -i \"$DIR_SRCIMG/*.jpg\" -i $Sound -vf deshake -c:v libx264 -acodec copy -flags global_header -pix_fmt yuv420p -s 1280x720  $OutFile"
#CMD="ffmpeg -thread_queue_size 1024 -framerate 24 -pattern_type glob -i \"$DIR_SRCIMG/*.jpg\" -i $Sound   -c:v libx264 -acodec copy -flags global_header -pix_fmt yuv420p -s 1280x720  $OutFile"
CMD="$FFMPEG -thread_queue_size 1024 -framerate 24 -pattern_type glob -i \"$DIR_SRCIMG/*.jpg\" $Sound -c:v libx264 -acodec copy -flags global_header -pix_fmt yuv420p -s 1280x720  $OutFile"
#CMD="ffmpeg -thread_queue_size 1024 -framerate 24 -pattern_type glob -i \"$DIR_SRCIMG/*.JPG\"   -c:v libx265 -acodec copy -flags global_header -pix_fmt yuv420p -s 1280x720  $OutFile"


echo "-----------------------------------------"
echo "$CMD"
echo "-----------------------------------------"
eval "$CMD"
cd "$baseDir" || exit 1

#ffmpeg -framerate 30 -pattern_type glob -i '*.jpg' -c:v libx264 ../ffmpeg-out-test.mp4
