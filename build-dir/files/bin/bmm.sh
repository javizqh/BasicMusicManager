#!/bin/bash

icon=$HOME/Code/Scripts/Icons/MusicIcon.png
music_directory=$HOME/Music
helpFile=$HOME/Code/Scripts/updateMusic/updateMusic.help
statisticsFile=$HOME/Music/.Statistics

usage() {
	echo -e "Usage: bmm [OPTIONS] ... \nTo display the help menu use: bmm --help" 1>&2
	exit 1
}

function update() {
	#Check and change all the songs in order to match their corresponding artist and album
	#they are in
	#TODO: optimize this. Now iterating 3 times per song. Don't now how this is faster than 1 iteration
	artists=$(ls $music_directory | tr " " "=")
	for artist in $artists; do
		nameArtist=$(echo $artist | tr "=" " ")
	  echo "Updating artist $nameArtist:"
		changeArtist "$nameArtist"
		albums=$(ls $music_directory/"$nameArtist" | tr " " "=")
		for album in $albums; do
			nameAlbum=$(echo $album | tr "=" " ")
			echo -e "\tAlbum $nameAlbum:"
			changeAlbum "$nameArtist" "$nameAlbum"
      # Change the cover
      eyeD3 --add-image "$music_directory/$nameArtist/$nameAlbum/.cover":FRONT_COVER "$music_directory/$nameArtist/$nameAlbum/"*.mp3 2&>1 >/dev/null
			cwd=$(pwd)
			cd "$music_directory"/"$nameArtist"/"$nameAlbum"
			songs=$(ls *.mp3 2>/dev/null | sed -E 's/.mp3//' | tr " " "=")
			cd "$cwd"
			for song in $songs; do
  			nameSong=$(echo $song | tr "=" " ")
			  echo -e "\t\tSong $nameSong"
			  changeTitle "$nameArtist" "$nameAlbum" "$nameSong"
			done
		done
	done
	statistic
	notificationFinish
}

#################### Rename Functions #########################
exitRename=0  # 0 = Not exit / 1 = Exit

function renameAll() {
	# Allow the user to fast rename songs
  exitRename=0
	artists=$(ls $music_directory | tr " " "=")
	for artist in $artists; do
		nameArtist=$(echo $artist | tr "=" " ")
		renameArtist "$nameArtist"
    if [ $exitRename = 1 ]; then
      break
    fi
	done
}

function renameArtist() {
  # $1 = artist
	# Allow the user to fast rename songs
  exitRename=0
  albums=$(ls $music_directory/"$1" | tr " " "=")
  for album in $albums; do
    nameAlbum=$(echo $album | tr "=" " ")
    renameAlbum "$1" "$nameAlbum"
    if [ $exitRename = 1 ]; then
      break
    fi
  done
}

function renameAlbum() {
  # $1 = artist
  # $2 = album
	# Allow the user to fast rename songs
  exitRename=0
  songs=$(ls $music_directory/"$1"/"$2" | tr " " "=")
  for song in $songs; do
    nameSong=$(echo $song | tr "=" " ")
    renameSong "$1" "$2" "$nameSong"
    if [ $exitRename = 1 ]; then
      break
    fi
  done
}

function renameSong() {
  # $1 = artist
  # $2 = album
  # $3 = song
	# Allow the user to fast rename songs
  exitRename=0
  nameSong=$(echo $3 | sed -e 's/.mp3//')
  artistAlbumLen=$(echo "$1: $2" | wc -m)
  artPadding=$((78 / 2 + $artistAlbumLen / 2))
  clear
  echo "┌───────────────────────────────────────────────────────────────────────────────┐"
  echo "│                                 MUSIC  EDITOR                                 │"
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  echo "│                                  RENAME SONG                                  │"
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  printf "│%*s%*s│\n" "$artPadding" "$1: $2" $((78-$artPadding+1)) " "
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  echo "│          Write the new name or empty to not modify, and press Enter.          │"
  echo "│                       If you want to finish write EXIT.                       │"
  echo "│                                                                               │"
  printf "│   Old name: \033[1;93m%-60s\033[0m      │\n" "$nameSong"
  echo "│   Rename:                                                                     │"
  echo "│                                                                               │"
  echo "└───────────────────────────────────────────────────────────────────────────────┘"
  # Realocate cursor position
  echo -en "\033[3A\033[12C"
  read newName
  if [ -z "$newName" ]; then return; fi
  if [ "$newName" = "$nameSong" ]; then return; fi
  if [ "$newName" = "EXIT" ]; then 
    exitRename=1
    return
  fi
  newName=$(echo "$newName" | sed 's/^[a-z]/\U&/g' | sed 's/ [a-z]/\U&/g')
  mv "$music_directory/$1/$2/$nameSong.mp3" "$music_directory/$1/$2/$newName.mp3"
  eyeD3 -t "$newName" "$music_directory/$1/$2/$newName".mp3 >/dev/null 2>/dev/null # Change title tag
}

#################### Rename Functions End #####################

function statistic() {
	rm $statisticsFile
	artists=$(ls $music_directory | tr " " "=")
	for artist in $artists; do
		nameArtist=$(echo $artist | tr "=" " ")
		allTimes=$(exiftool -duration $music_directory/"$nameArtist"/* | grep -e ':.* ' | sed -E 's/(^[^:]*:)//' | awk '{print $1}')
		artistDuration=$(calcTime $allTimes)
		artistSongs=$(ls "$music_directory"/"$nameArtist" -R | grep .mp3 | wc -l)
		artistAlbums=$(ls "$music_directory"/"$nameArtist" -p | grep '/' | wc -l)
		echo -e "$nameArtist\tAlbums: $artistAlbums\tSongs: $artistSongs\tDuration: $artistDuration" >>$statisticsFile
		albums=$(ls $music_directory/"$nameArtist" | tr " " "=")
		for album in $albums; do
			nameAlbum=$(echo $album | tr "=" " ")
			times=$(exiftool -duration $music_directory/"$nameArtist"/"$nameAlbum"/* | grep -e ':.* ' | sed -E 's/(^[^:]*:)//' | awk '{print $1}')
			albumDuration=$(calcTime $times)
			albumSongs=$(ls "$music_directory"/"$nameArtist"/"$nameAlbum" -R | grep .mp3 | wc -l)
			echo -e "\t$nameAlbum\t$albumSongs songs\t$albumDuration" >>$statisticsFile
		done
	done
}

function calcTime() {
	totalH=0
	totalM=0
	totalS=0
	for i in $@; do
	  if ( echo $i | grep ':' >/dev/null); then
		  time=$(echo $i | tr ":" "\t")
		  H=$(echo $time | awk '{print $1}')
		  M=$(echo $time | awk '{print $2}')
		  S=$(echo $time | awk '{print $3}')
		  totalH=$((10#$totalH + 10#$H))
		  totalM=$((10#$totalM + 10#$M))
		  if [[ $((10#$totalM)) -gt 59 ]]; then
			  totalH=$((10#$totalH + 10#1))
			  totalM=$((10#$totalM - 10#60))
		  fi
		  totalS=$((10#$totalS + 10#$S))
		  if [[ $((10#$totalS)) -gt 59 ]]; then
			  totalM=$((10#$totalM + 10#1))
			  totalS=$((10#$totalS - 10#60))
		  fi
		 else
		  S=$(echo $i | tr "." "\t" | awk '{print $1}')
		  totalS=$((10#$totalS + 10#$S))
		  if [[ $((10#$totalS)) -gt 59 ]]; then
			  totalM=$((10#$totalM + 10#1))
			  totalS=$((10#$totalS - 10#60))
		  fi
		 fi
	done
  if [[ $((10#$totalM)) -gt 59 ]]; then
	  totalH=$((10#$totalH + 10#1))
	  totalM=$((10#$totalM - 10#60))
  fi
	#Make the numbers always be 00 or 07 or 18 ...
	if [[ $((10#$totalH)) -lt 10 ]]; then totalH=$(echo "0$totalH"); fi
	if [[ $((10#$totalM)) -lt 10 ]]; then totalM=$(echo "0$totalM"); fi
	if [[ $((10#$totalS)) -lt 10 ]]; then totalS=$(echo "0$totalS"); fi
	echo "$totalH:$totalM:$totalS"
}

function compress() {
  clear
  tar -vczf "$music_directory/MyMusic.tgz" "$music_directory"
	notificationFinish
}

function new() {
	# $1 = artist
	# Create artist directory if already display current albums
	if [ -d $music_directory/"$1" ]; then
		echo -n "The current albums in $1 are: "
		ls $music_directory/"$1"
	else
		mkdir $music_directory/"$1"
	fi
	# Request albums name and create directories with them
	echo "Introduce the name of the album then press enter, when you have finished press enter again"
	while createAlbums "$1"; do :; done
}

function newArtist() {
	# $1 = artist
	# Create artist directory
	if [ ! -d $music_directory/"$1" ]; then
		mkdir $music_directory/"$1"
	fi
}

function newAlbum() {
	# $1 = artist
	# $2 = album
	# Create album directory
	if [ ! -d $music_directory/"$1"/"$2" ]; then
		mkdir $music_directory/"$1"/"$2"
	fi
}

function newSong() {
	# $1 = artist
	# $2 = album
	# $3 = song
	# $4 = original place
	# Create song copying from directory
	if [ ! -d $music_directory/"$1"/"$2"/"$3" ]; then
		cp "$4" $music_directory/"$1"/"$2"/"$3".mp3
	fi
}

function createAlbums() {
	# $1 = artist
	echo -n "Introduce album name: "
	read album
	# if album = "" then return 1
	if [ -z "$album" ]; then return 1; fi
	#if already exists do nothing, if not create directory
	if [ -d $music_directory/"$1"/"$album" ]; then return; fi
	mkdir $music_directory/"$1"/"$album"
}

function changeArtist() {
	# $1 = artistName and artistDirectory
	cwd=$(pwd)
	# Check if artist directory exists
	checkArtist "$1"
	if [ -n "$2" ]; then
		checkAlbum "$1" "$2"
		cd $music_directory/"$1"/"$2"
	else
		cd $music_directory/"$1"
	fi

	changeArtistTag "$1"
	cd "$cwd"
}

function changeArtistTag() {
	# $1 = artist
	eyeD3 -a "$1" *.mp3 >/dev/null 2>/dev/null # Change artist tag
	for albums in $(ls | tr " " "=" | grep -v '\..*$'); do
		album=$(echo $albums | tr "=" " ")
		eyeD3 -a "$1" "$album"/*.mp3 >/dev/null 2>/dev/null
		eyeD3 -b "$1" "$album"/*.mp3 >/dev/null 2>/dev/null
		eyeD3 --composer "$1" "$album"/*.mp3 >/dev/null 2>/dev/null
	done
}

function changeAlbum() {
	# $1 = artistName and artistDirectory
	# $2 = albumName and albumDirectory
	cwd=$(pwd)
	# Check if artist directory and album directory exists
	checkArtist "$1"
	checkAlbum "$1" "$2"
	cd $music_directory/"$1"/"$2"
	eyeD3 -A "$2" *.mp3 >/dev/null 2>/dev/null # Change album tag
	cd "$cwd"
}

function changeTitle() {
	# $1 = artistName and artistDirectory
	# $2 = albumName and albumDirectory
	# $3 = songName
	# Check if artist directory and album directory exists
	checkArtist "$1"
	checkAlbum "$1" "$2"
	eyeD3 -t "$3" "$music_directory"/"$1"/"$2"/"$3".mp3 >/dev/null 2>/dev/null # Change title tag
}

function download() {
	# $1 = url
	# $2/$3 = artistName/albumName
	# $4 = songName
	cwd=$(pwd)
	#Check if artsistName and albumName exist
	checkArtist "$2"
	if [ -n "$3" ]; then
		checkAlbum "$2" "$3"
		cd $music_directory/"$2"/"$3"
	else
		cd $music_directory/"$2"
	fi

	# Check if song already exists, if true then do nothing else download
	if (ls | grep "$4" >/dev/null); then
		echo "The song $4 already exists in '$2/$3'"
	else
		yt-dlp -x --add-metadata -o "$4.%(ext)s" --audio-format mp3 $1 >/dev/null
		eyeD3 -t "$4" "$4".mp3 >/dev/null 2>/dev/null # Change title tag
		notificationAdded "$4"
	fi
	cd "$cwd"
	changeArtist "$2" "$3"
	changeAlbum "$2" "$3"
}

function checkArtist() {
	if ! [ -d "$music_directory"/"$1" ]; then
		echo "The artist $1 does not exist" 1>&2
		exit 1
	fi
}

function checkAlbum() {
	if ! [ -d "$music_directory"/"$1"/"$2" ]; then
		echo "The album $2 does not exist" 1>&2
		exit 1
	fi
}

function send() {
	# Check if the device connection is off
	if ! (timeout -k 0 5 $HOME/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/service/daemon.js -a >/dev/null); then
		echo "Error: the device connection is off" 1>&2
		exit 1
	fi
	# Check if there are devices availables
	if [ $($HOME/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/service/daemon.js -a | wc -l) -eq 0 ]; then
		echo "Error: no devices available" 1>&2
		exit 1
	fi
	status=$($HOME/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/service/daemon.js -a | tr -d " " | awk '{print $4}')
	if ! (echo $status | grep -v 'false' >/dev/null); then
		echo "Error: no devices available" 1>&2
		exit 1
	fi
	# Check if $1 = null connect if there is only one device
	if [ -z $1 ]; then
		Ip=$($HOME/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/service/daemon.js -l)
	else
		# If $1 = Ip try to connect
		availableIp=$($HOME/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/service/daemon.js -l)
		if (echo $availableIp | grep $1 >/dev/null); then
			Ip=$1
		else
			echo "Device $1 not found" 1>&2
			exit 1
		fi
	fi
	shareMusic $Ip
	deviceName=$($HOME/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/service/daemon.js -a | grep $Ip | tr " " "=" | awk '{print $2}' | tr "=" " ")
	notificationMobile "$deviceName"
}

function shareMusic() {
	# $1 = device Ip
	cwd=$(pwd)
	cd $music_directory
	touch ."$1".list # Write Artist/Album/Song\n
	for artists in $(ls | tr " " "=" | grep -v '\..*$'); do
		artist=$(echo $artists | tr "=" " ")
		for albums in $(ls "$artist" | tr " " "=" | grep -v '\..*$'); do
			album=$(echo $albums | tr "=" " ")
			songs=$(ls "$artist"/"$album" | tr " " "=")
			toSend $1 "$artist" "$album" $songs
		done
	done
	cd "$cwd"
}

function toSend() {
	DeviceFile=."$1".list
	Ip=$1
	shift
	artist="$1"
	shift
	album="$1"
	shift
	for songName in $@; do
		song=$(echo $songName | tr "=" " ")
		if (grep -e "$artist"/"$album"/"$song" $DeviceFile >/dev/null); then continue; fi
		$HOME/.local/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/service/daemon.js -d $Ip --share-file="$music_directory/$artist/$album/$song"
		echo "$artist/$album/$song" >>$DeviceFile
	done
}

notificationAdded() {
	notify-send "updateMusic.sh" "The song <b>$1</b> has been added succesfully" --icon=$icon
}

notificationFinish() {
	notify-send "updateMusic.sh" "The music has been updated" --icon=$icon
}

notificationMobile() {
	notify-send "updateMusic.sh" "The device <b>$1</b> music has been updated" --icon=$icon
}

help() {
	cat $helpFile
	exit 0
}

############# Interface ########################################
function mainMenu() {
  menuNum=1
  printMainMenu 1
  while read -rsn1 ui; do
      case "$ui" in
        $'\x1b')    # Handle ESC sequence.
          # Flush read. We account for sequences for Fx keys as
          # well. 6 should suffice far more then enough.
          read -rsn1 -t 0.1 tmp
          if [[ "$tmp" == "[" ]]; then
              read -rsn1 -t 0.1 tmp
              case "$tmp" in
              "A")
                if [ $menuNum -gt 1 ]; then
                  let menuNum--
                else
                  menuNum=9
                fi
                printMainMenu $menuNum
              ;;
              "B")
                if [ $menuNum -lt 9 ]; then
                  let menuNum++
                else
                  menuNum=1
                fi
                printMainMenu $menuNum
              ;;
              esac
          fi
          # Flush "stdin" with 0.1  sec timeout.
          read -rsn5 -t 0.1
          ;;
        "")
          selectOption $menuNum
        ;;
      esac
  done
}

selectOption() {
  case $1 in
    "1")
      clear
      update
      mainMenu
    ;;
    "2")
      #TODO: improve 
      #downloadMenu
      printDownloadMenu
      clear
      mainMenu
    ;;
    "3") 
      #Browse Menu to Add or view song data
      browseArtistMenu
    ;;
    "4") 
      renameArtistMenu
    ;;
    "5")
      # Add cover
      addCoverArtistMenu
    ;;
    "6")
      compress
      mainMenu
    ;;
    "7") 
      #StatisticsMenu
      #TODO: remade with fancy python
      cat $music_directory/.Statistics
    ;;
    "8")
      creditsMenu
    ;;
    "9")
      clear
      exit 0
    ;;
  esac
}

function printMainMenu() {
  clear
  echo "┌───────────────────────────────────────────────────────────────────────────────┐"
  echo "│                                 MUSIC  EDITOR                                 │"
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  echo "│                Select using the arrow keys, then press enter.                 │"
  echo "│                                                                               │"
  if [[ "$1" == "1" ]]; then
    echo -e "│   \033[101m¬ Update all\033[0m                                                                │"
  else
    echo "│   ¬ Update all                                                                │"
  fi
  if [[ "$1" == "2" ]]; then
    echo -e "│   \033[101m¬ Download new song\033[0m                                                         │"
  else
    echo "│   ¬ Download new song                                                         │"
  fi
  if [[ "$1" == "3" ]]; then
    echo -e "│   \033[101m¬ Browse songs\033[0m                                                              │"
  else
    echo "│   ¬ Browse songs                                                              │"
  fi
  if [[ "$1" == "4" ]]; then
    echo -e "│   \033[101m¬ Rename songs\033[0m                                                              │"
  else
    echo "│   ¬ Rename songs                                                              │"
  fi
  if [[ "$1" == "5" ]]; then
    echo -e "│   \033[101m¬ Add cover\033[0m                                                                 │"
  else
    echo "│   ¬ Add cover                                                                 │"
  fi
  if [[ "$1" == "6" ]]; then
    echo -e "│   \033[101m¬ Export data\033[0m                                                               │"
  else
    echo "│   ¬ Export data                                                               │"
  fi
  if [[ "$1" == "7" ]]; then
    echo -e "│   \033[101m¬ View stadistics\033[0m                                                           │"
  else
    echo "│   ¬ View stadistics                                                           │"
  fi
  if [[ "$1" == "8" ]]; then
    echo -e "│   \033[101m¬ Credits\033[0m                                                                   │"
  else
    echo "│   ¬ Credits                                                                   │"
  fi
  if [[ "$1" == "9" ]]; then
    echo -e "│   \033[101m¬ Exit\033[0m                                                                      │"
  else
    echo "│   ¬ Exit                                                                      │"
  fi
  echo "│                                                                               │"
  echo "└───────────────────────────────────────────────────────────────────────────────┘"
  # Add credits and more stuff
}

function printDownloadMenu() {
  # Try to improve
  clear
  echo "┌───────────────────────────────────────────────────────────────────────────────┐"
  echo "│                                 MUSIC EDITOR                                  │"
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  echo "│                                DOWNLOAD  MENU                                 │"
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  echo "│                      Write EXIT to go back to main menu                       │"
  echo "│                                                                               │"
  echo "│      Artist:                                                                  │"
  echo "│      Album:                                                                   │"
  echo "│      Song name:                                                               │"
  echo "│      Url:                                                                     │"
  echo "│                                                                               │"
  echo "└───────────────────────────────────────────────────────────────────────────────┘"
  # Realocate cursor position
  echo -en "\033[6A\033[15C"
  # Read Artist name
  read downArt
  if [ "$downArt" = "EXIT" ]; then
    return
  fi
  # Read Album name
  echo -en "\033[14C"
  read downAlb
  if [ "$downAlb" = "EXIT" ]; then
    return
  fi
  # Read Song name
  echo -en "\033[18C"
  read downSng
  if [ "$downSng" = "EXIT" ]; then
    return
  fi
  # Read Url
  echo -en "\033[12C"
  read downUrl
  if [ "$downUrl" = "EXIT" ]; then
    return
  fi
  download "$downUrl" "$downArt" "$downAlb" "$downSng"
}

function creditsMenu() {
  printCredits
  while read -rsn1 ui; do
    if [[ "$ui" == "" ]]; then
      mainMenu
    fi
  done
}

function printCredits() {
  clear
  echo "┌───────────────────────────────────────────────────────────────────────────────┐"
  echo "│                                 MUSIC  EDITOR                                 │"
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  echo "│                                    CREDITS                                    │"
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  echo "│                             Press Enter to return.                            │"
  echo "│                                                                               │"
  echo "│   ¬ Main creator: Javier Izquierdo <javizqh@gmail.com>                        │"
  echo "│   ¬ Main creator github: https://github.com/javizqh                           │"
  echo "│   ¬ eyeD3 from Nicfit https://github.com/nicfit/eyeD3                         │"
  echo "│   ¬ yt-dlp from yt-dlp https://github.com/yt-dlp/yt-dlp                       │"
  echo "│                                                                               │"
  echo "└───────────────────────────────────────────────────────────────────────────────┘"
  # Add credits and more stuff
}

########### Browse Artist Menu #############
function browseArtistMenu() {
  browseArtistMenuNum=1
  maxBrowseArtistMenuNum=$(ls $music_directory | wc -l)
  maxBrowseArtistMenuNum=$(($maxBrowseArtistMenuNum + 2))
  printArtistMenu 1 "BROWSE MENU"
  while read -rsn1 ui; do
      case "$ui" in
        $'\x1b')    # Handle ESC sequence.
          # Flush read. We account for sequences for Fx keys as
          # well. 6 should suffice far more then enough.
          read -rsn1 -t 0.1 tmp
          if [[ "$tmp" == "[" ]]; then
              read -rsn1 -t 0.1 tmp
              case "$tmp" in
              "A")
                if [ $browseArtistMenuNum -gt 1 ]; then
                  let browseArtistMenuNum--
                else
                  browseArtistMenuNum=$maxBrowseArtistMenuNum
                fi
                printArtistMenu $browseArtistMenuNum "BROWSE MENU"
              ;;
              "B")
                if [ $browseArtistMenuNum -lt $maxBrowseArtistMenuNum ]; then
                  let browseArtistMenuNum++
                else
                  browseArtistMenuNum=1
                fi
                printArtistMenu $browseArtistMenuNum "BROWSE MENU"
              ;;
              "C")
                if [ $browseArtistMenuNum -le $(($maxBrowseArtistMenuNum - 7)) ]; then
                  browseArtistMenuNum=$(($browseArtistMenuNum + 7))
                else
                  browseArtistMenuNum=$maxBrowseArtistMenuNum
                fi
                printArtistMenu $browseArtistMenuNum "BROWSE MENU"
              ;;
              "D")
                if [ $browseArtistMenuNum -ge $((1 + 7)) ]; then
                  browseArtistMenuNum=$(($browseArtistMenuNum - 7))
                else
                  browseArtistMenuNum=1
                fi
                printArtistMenu $browseArtistMenuNum "BROWSE MENU"
              ;;
              esac
          fi
          # Flush "stdin" with 0.1  sec timeout.
          read -rsn5 -t 0.1
          ;;
        "")
          selectOptionBrowseArtist $browseArtistMenuNum
        ;;
      esac
  done
}

selectOptionBrowseArtist() {
  case $1 in
    "1")
      mainMenu
    ;;
    "2")
      echo -n "Create new artist: " 
      read name
      newArtist "$name"
      browseArtistMenu
    ;;
    *)
      artist=$(ls $music_directory | sed -n "$(($1 - 2))p")
      browseAlbumMenu "$artist"
    ;;
  esac
}
############################################

########### Browse Album Menu ##############
function browseAlbumMenu() {
  # $1 = artist name
  browseAlbumMenuNum=1
  maxBrowseAlbumMenuNum=$(ls $music_directory/"$1" | wc -l)
  maxBrowseAlbumMenuNum=$((maxBrowseAlbumMenuNum+2))
  printAlbumMenu 1 "BROWSE MENU" "$1"
  while read -rsn1 ui; do
      case "$ui" in
        $'\x1b')    # Handle ESC sequence.
          # Flush read. We account for sequences for Fx keys as
          # well. 6 should suffice far more then enough.
          read -rsn1 -t 0.1 tmp
          if [[ "$tmp" == "[" ]]; then
              read -rsn1 -t 0.1 tmp
              case "$tmp" in
              "A")
                if [ $browseAlbumMenuNum -gt 1 ]; then
                  let browseAlbumMenuNum--
                else
                  browseAlbumMenuNum=$maxBrowseAlbumMenuNum
                fi
                printAlbumMenu $browseAlbumMenuNum "BROWSE MENU" "$1"
              ;;
              "B")
                if [ $browseAlbumMenuNum -lt $maxBrowseAlbumMenuNum ]; then
                  let browseAlbumMenuNum++
                else
                  browseAlbumMenuNum=1
                fi
                printAlbumMenu $browseAlbumMenuNum "BROWSE MENU" "$1"
              ;;
              "C")
                if [ $browseAlbumMenuNum -le $(($maxBrowseAlbumMenuNum - 7)) ]; then
                  browseAlbumMenuNum=$(($browseAlbumMenuNum + 7))
                else
                  browseAlbumMenuNum=$maxBrowseAlbumMenuNum
                fi
                printAlbumMenu $browseAlbumMenuNum "BROWSE MENU" "$1"
              ;;
              "D")
                if [ $browseAlbumMenuNum -ge $((1 + 7)) ]; then
                  browseAlbumMenuNum=$(($browseAlbumMenuNum - 7))
                else
                  browseAlbumMenuNum=1
                fi
                printAlbumMenu $browseAlbumMenuNum "BROWSE MENU" "$1"
              ;;
              esac
          fi
          # Flush "stdin" with 0.1  sec timeout.
          read -rsn5 -t 0.1
          ;;
        "")
          selectOptionBrowseAlbum $browseAlbumMenuNum "$1"
        ;;
      esac
  done
}

selectOptionBrowseAlbum() {
  # $1 = selected menu
  # $2 = artist name 
  case $1 in
    "1")
      browseArtistMenu
    ;;
    "2")
      echo -n "Create new album: "
      read name
      newAlbum "$2" "$name"
      browseAlbumMenu "$2"
    ;;
    *)
      album=$(ls $music_directory/"$2" | sed -n "$(($1 - 2))p")
      browseSongMenu "$2" "$album"
    ;;
  esac
}
############################################

########### Browse Song Menu ###############
function browseSongMenu() {
  # $1 = artist name
  # $2 = album name
  browseSongMenuNum=1
  maxBrowseSongMenuNum=$(ls $music_directory/"$1"/"$2" | wc -l)
  maxBrowseSongMenuNum=$((maxBrowseSongMenuNum+2))
  printSongMenu 1 "BROWSE MENU" "$1" "$2"
  while read -rsn1 ui; do
      case "$ui" in
        $'\x1b')    # Handle ESC sequence.
          # Flush read. We account for sequences for Fx keys as
          # well. 6 should suffice far more then enough.
          read -rsn1 -t 0.1 tmp
          if [[ "$tmp" == "[" ]]; then
              read -rsn1 -t 0.1 tmp
              case "$tmp" in
              "A")
                if [ $browseSongMenuNum -gt 1 ]; then
                  let browseSongMenuNum--
                else
                  browseSongMenuNum=$maxBrowseSongMenuNum
                fi
                printSongMenu $browseSongMenuNum "BROWSE MENU" "$1" "$2"
              ;;
              "B")
                if [ $browseSongMenuNum -lt $maxBrowseSongMenuNum ]; then
                  let browseSongMenuNum++
                else
                  browseSongMenuNum=1
                fi
                printSongMenu $browseSongMenuNum "BROWSE MENU" "$1" "$2"
              ;;
              "C")
                if [ $browseSongMenuNum -le $(($maxBrowseSongMenuNum - 7)) ]; then
                  browseSongMenuNum=$(($browseSongMenuNum + 7))
                else
                  browseSongMenuNum=$maxBrowseSongMenuNum
                fi
                printSongMenu $browseSongMenuNum "BROWSE MENU" "$1" "$2"
              ;;
              "D")
                if [ $browseSongMenuNum -ge $((1 + 7)) ]; then
                  browseSongMenuNum=$(($browseSongMenuNum - 7))
                else
                  browseSongMenuNum=1
                fi
                printSongMenu $browseSongMenuNum "BROWSE MENU" "$1" "$2"
              ;;
              esac
          fi
          # Flush "stdin" with 0.1  sec timeout.
          read -rsn5 -t 0.1
          ;;
        "")
          selectOptionBrowseSong $browseSongMenuNum "$1" "$2"
        ;;
      esac
  done
}

selectOptionBrowseSong() {
  # $1 = selected menu
  # $2 = artist name 
  # $3 = album name 
  case $1 in
    "1")
      browseAlbumMenu "$2"
    ;;
    "2")
      echo -n "Create new song: "
      read name
      echo -n "Absolute path to song file: "
      read path
      newSong "$2" "$3" "$name" "$path"
      browseSongMenu "$2" "$3"
    ;;
    *) 
      song=$(ls $music_directory/"$2"/"$3" | sed -n "$(($1 - 2))p")
      echo "Selected $song"
    ;;
  esac
}
############################################

########### Rename Artist Menu #############
function renameArtistMenu() {
  renameArtistMenuNum=1
  maxrenameArtistMenuNum=$(ls $music_directory | wc -l)
  let maxrenameArtistMenuNum++
  printArtistMenu 1 "RENAME MENU"
  while read -rsn1 ui; do
      case "$ui" in
        $'\x1b')    # Handle ESC sequence.
          # Flush read. We account for sequences for Fx keys as
          # well. 6 should suffice far more then enough.
          read -rsn1 -t 0.1 tmp
          if [[ "$tmp" == "[" ]]; then
              read -rsn1 -t 0.1 tmp
              case "$tmp" in
              "A")
                if [ $renameArtistMenuNum -gt 1 ]; then
                  let renameArtistMenuNum--
                else
                  renameArtistMenuNum=$maxrenameArtistMenuNum
                fi
                printArtistMenu $renameArtistMenuNum "RENAME MENU"
              ;;
              "B")
                if [ $renameArtistMenuNum -lt $maxrenameArtistMenuNum ]; then
                  let renameArtistMenuNum++
                else
                  renameArtistMenuNum=1
                fi
                printArtistMenu $renameArtistMenuNum "RENAME MENU"
              ;;
              "C")
                if [ $renameArtistMenuNum -le $(($maxrenameArtistMenuNum - 7)) ]; then
                  renameArtistMenuNum=$(($renameArtistMenuNum + 7))
                else
                  renameArtistMenuNum=$maxrenameArtistMenuNum
                fi
                printArtistMenu $renameArtistMenuNum "RENAME MENU"
              ;;
              "D")
                if [ $renameArtistMenuNum -ge $((1 + 7)) ]; then
                  renameArtistMenuNum=$(($renameArtistMenuNum - 7))
                else
                  renameArtistMenuNum=1
                fi
                printArtistMenu $renameArtistMenuNum "RENAME MENU"
              ;;
              esac
          fi
          # Flush "stdin" with 0.1  sec timeout.
          read -rsn5 -t 0.1
          ;;
        "")
          selectOptionRenameArtist $renameArtistMenuNum
        ;;
      esac
  done
}

selectOptionRenameArtist() {
  case $1 in
    "1")
      mainMenu
    ;;
    *) 
      artist=$(ls $music_directory | sed -n "$(($1 - 1))p")
      renameAlbumMenu "$artist"
    ;;
  esac
}
############################################

########### Rename Album Menu ##############
function renameAlbumMenu() {
  # $1 = artist name
  renameAlbumMenuNum=1
  maxrenameAlbumMenuNum=$(ls $music_directory/"$1" | wc -l)
  maxrenameAlbumMenuNum=$((maxrenameAlbumMenuNum+2))
  printAlbumMenu 1 "RENAME MENU" "$1"
  while read -rsn1 ui; do
      case "$ui" in
        $'\x1b')    # Handle ESC sequence.
          # Flush read. We account for sequences for Fx keys as
          # well. 6 should suffice far more then enough.
          read -rsn1 -t 0.1 tmp
          if [[ "$tmp" == "[" ]]; then
              read -rsn1 -t 0.1 tmp
              case "$tmp" in
              "A")
                if [ $renameAlbumMenuNum -gt 1 ]; then
                  let renameAlbumMenuNum--
                else
                  renameAlbumMenuNum=$maxrenameAlbumMenuNum
                fi
                printAlbumMenu $renameAlbumMenuNum "RENAME MENU" "$1"
              ;;
              "B")
                if [ $renameAlbumMenuNum -lt $maxrenameAlbumMenuNum ]; then
                  let renameAlbumMenuNum++
                else
                  renameAlbumMenuNum=1
                fi
                printAlbumMenu $renameAlbumMenuNum "RENAME MENU" "$1"
              ;;
              "C")
                if [ $renameAlbumMenuNum -le $(($maxrenameAlbumMenuNum - 7)) ]; then
                  renameAlbumMenuNum=$(($renameAlbumMenuNum + 7))
                else
                  renameAlbumMenuNum=$maxrenameAlbumMenuNum
                fi
                printAlbumMenu $renameAlbumMenuNum "RENAME MENU" "$1"
              ;;
              "D")
                if [ $renameAlbumMenuNum -ge $((1 + 7)) ]; then
                  renameAlbumMenuNum=$(($renameAlbumMenuNum - 7))
                else
                  renameAlbumMenuNum=1
                fi
                printAlbumMenu $renameAlbumMenuNum "RENAME MENU" "$1"
              ;;
              esac
          fi
          # Flush "stdin" with 0.1  sec timeout.
          read -rsn5 -t 0.1
          ;;
        "")
          selectOptionRenameAlbum $renameAlbumMenuNum "$1"
        ;;
      esac
  done
}

selectOptionRenameAlbum() {
  # $1 = selected menu
  # $2 = artist name 
  case $1 in
    "1")
      renameArtistMenu
    ;;
    "2")
      #All albums
      renameArtist "$2"
      renameAlbumMenu "$2"
    ;;
    *)
      album=$(ls $music_directory/"$2" | sed -n "$(($1 - 2))p")
      renameSongMenu "$2" "$album"
    ;;
  esac
}
############################################

########### Rename Song Menu ###############
function renameSongMenu() {
  # $1 = artist name
  # $2 = album name
  renameSongMenuNum=1
  maxrenameSongMenuNum=$(ls $music_directory/"$1"/"$2" | wc -l)
  maxrenameSongMenuNum=$((maxrenameSongMenuNum+2))
  printSongMenu 1 "RENAME MENU" "$1" "$2"
  while read -rsn1 ui; do
      case "$ui" in
        $'\x1b')    # Handle ESC sequence.
          # Flush read. We account for sequences for Fx keys as
          # well. 6 should suffice far more then enough.
          read -rsn1 -t 0.1 tmp
          if [[ "$tmp" == "[" ]]; then
              read -rsn1 -t 0.1 tmp
              case "$tmp" in
              "A")
                if [ $renameSongMenuNum -gt 1 ]; then
                  let renameSongMenuNum--
                else
                  renameSongMenuNum=$maxrenameSongMenuNum
                fi
                printSongMenu $renameSongMenuNum "RENAME MENU" "$1" "$2"
              ;;
              "B")
                if [ $renameSongMenuNum -lt $maxrenameSongMenuNum ]; then
                  let renameSongMenuNum++
                else
                  renameSongMenuNum=1
                fi
                printSongMenu $renameSongMenuNum "RENAME MENU" "$1" "$2"
              ;;
              "C")
                if [ $renameSongMenuNum -le $(($maxrenameSongMenuNum - 7)) ]; then
                  renameSongMenuNum=$(($renameSongMenuNum + 7))
                else
                  renameSongMenuNum=$maxrenameSongMenuNum
                fi
                printSongMenu $renameSongMenuNum "RENAME MENU" "$1" "$2"
              ;;
              "D")
                if [ $renameSongMenuNum -ge $((1 + 7)) ]; then
                  renameSongMenuNum=$(($renameSongMenuNum - 7))
                else
                  renameSongMenuNum=1
                fi
                printSongMenu $renameSongMenuNum "RENAME MENU" "$1" "$2"
              ;;
              esac
          fi
          # Flush "stdin" with 0.1  sec timeout.
          read -rsn5 -t 0.1
          ;;
        "")
          selectOptionRenameSong $renameSongMenuNum "$1" "$2"
        ;;
      esac
  done
}

selectOptionRenameSong() {
  # $1 = selected menu
  # $2 = artist name 
  # $3 = album name 
  case $1 in
    "1")
      renameAlbumMenu "$2"
    ;;
    "2")
      #All Songs
      renameAlbum "$2" "$3"
      renameAlbumMenu "$2"
    ;;
    *) 
      song=$(ls $music_directory/"$2"/"$3" | sed -n "$(($1 - 2))p")
      renameSong "$2" "$3" "$song"
      renameSongMenu "$2" "$3"
    ;;
  esac
}
############################################

########### AddCover Artist Menu #############
function addCoverArtistMenu() {
  addCoverArtistMenuNum=1
  maxaddCoverArtistMenuNum=$(ls $music_directory | wc -l)
  let maxaddCoverArtistMenuNum++
  printArtistMenu 1 "ADD COVER MENU"
  while read -rsn1 ui; do
      case "$ui" in
        $'\x1b')    # Handle ESC sequence.
          # Flush read. We account for sequences for Fx keys as
          # well. 6 should suffice far more then enough.
          read -rsn1 -t 0.1 tmp
          if [[ "$tmp" == "[" ]]; then
              read -rsn1 -t 0.1 tmp
              case "$tmp" in
              "A")
                if [ $addCoverArtistMenuNum -gt 1 ]; then
                  let addCoverArtistMenuNum--
                else
                  addCoverArtistMenuNum=$maxaddCoverArtistMenuNum
                fi
                printArtistMenu $addCoverArtistMenuNum "ADD COVER MENU"
              ;;
              "B")
                if [ $addCoverArtistMenuNum -lt $maxaddCoverArtistMenuNum ]; then
                  let addCoverArtistMenuNum++
                else
                  addCoverArtistMenuNum=1
                fi
                printArtistMenu $addCoverArtistMenuNum "ADD COVER MENU"
              ;;
              "C")
                if [ $addCoverArtistMenuNum -le $(($maxaddCoverArtistMenuNum - 7)) ]; then
                  addCoverArtistMenuNum=$(($addCoverArtistMenuNum + 7))
                else
                  addCoverArtistMenuNum=$maxaddCoverArtistMenuNum
                fi
                printArtistMenu $addCoverArtistMenuNum "ADD COVER MENU"
              ;;
              "D")
                if [ $addCoverArtistMenuNum -ge $((1 + 7)) ]; then
                  addCoverArtistMenuNum=$(($addCoverArtistMenuNum - 7))
                else
                  addCoverArtistMenuNum=1
                fi
                printArtistMenu $addCoverArtistMenuNum "ADD COVER MENU"
              ;;
              esac
          fi
          # Flush "stdin" with 0.1  sec timeout.
          read -rsn5 -t 0.1
          ;;
        "")
          selectOptionAddCoverArtist $addCoverArtistMenuNum
        ;;
      esac
  done
}

selectOptionAddCoverArtist() {
  case $1 in
    "1")
      mainMenu
    ;;
    *) 
      artist=$(ls $music_directory | sed -n "$(($1 - 1))p")
      addCoverAlbumMenu "$artist"
    ;;
  esac
}
############################################

########### AddCover Album Menu ##############
function addCoverAlbumMenu() {
  # $1 = artist name
  addCoverAlbumMenuNum=1
  maxaddCoverAlbumMenuNum=$(ls $music_directory/"$1" | wc -l)
  maxaddCoverAlbumMenuNum=$((maxaddCoverAlbumMenuNum+1))
  printAlbumMenu 1 "ADD COVER MENU" "$1"
  while read -rsn1 ui; do
      case "$ui" in
        $'\x1b')    # Handle ESC sequence.
          # Flush read. We account for sequences for Fx keys as
          # well. 6 should suffice far more then enough.
          read -rsn1 -t 0.1 tmp
          if [[ "$tmp" == "[" ]]; then
              read -rsn1 -t 0.1 tmp
              case "$tmp" in
              "A")
                if [ $addCoverAlbumMenuNum -gt 1 ]; then
                  let addCoverAlbumMenuNum--
                else
                  addCoverAlbumMenuNum=$maxaddCoverAlbumMenuNum
                fi
                printAlbumMenu $addCoverAlbumMenuNum "ADD COVER MENU" "$1"
              ;;
              "B")
                if [ $addCoverAlbumMenuNum -lt $maxaddCoverAlbumMenuNum ]; then
                  let addCoverAlbumMenuNum++
                else
                  addCoverAlbumMenuNum=1
                fi
                printAlbumMenu $addCoverAlbumMenuNum "ADD COVER MENU" "$1"
              ;;
              "C")
                if [ $addCoverAlbumMenuNum -le $(($maxaddCoverAlbumMenuNum - 7)) ]; then
                  addCoverAlbumMenuNum=$(($addCoverAlbumMenuNum + 7))
                else
                  addCoverAlbumMenuNum=$maxaddCoverAlbumMenuNum
                fi
                printAlbumMenu $addCoverAlbumMenuNum "ADD COVER MENU" "$1"
              ;;
              "D")
                if [ $addCoverAlbumMenuNum -ge $((1 + 7)) ]; then
                  addCoverAlbumMenuNum=$(($addCoverAlbumMenuNum - 7))
                else
                  addCoverAlbumMenuNum=1
                fi
                printAlbumMenu $addCoverAlbumMenuNum "ADD COVER MENU" "$1"
              ;;
              esac
          fi
          # Flush "stdin" with 0.1  sec timeout.
          read -rsn5 -t 0.1
          ;;
        "")
          selectOptionAddCoverAlbum $addCoverAlbumMenuNum "$1"
        ;;
      esac
  done
}

selectOptionAddCoverAlbum() {
  # $1 = selected menu
  # $2 = artist name 
  case $1 in
    "1")
      addCoverArtistMenu
    ;;
    *)
      album=$(ls $music_directory/"$2" | sed -n "$(($1 - 1))p")
      echo -n "Absolute path to cover file: "
      read path
      path=$(echo $path | tr -d "'" )
      if ( cp "$path" "$music_directory/$2/$album/.cover" 1>/dev/null 2>/dev/null ); then
        eyeD3 --add-image "$music_directory/$2/$album/.cover":FRONT_COVER "$music_directory/$2/$album/"*.mp3 1>/dev/null 2>/dev/null
        addCoverAlbumMenu "$2"
      else
        echo Error: File not found
      fi
    ;;
  esac
}
############################################

########### Reusable Menus #################
function printArtistMenu() {
  # $1 = selected menu
  # $2 = type of menu
  # Calculate selected page
  artists=$(ls $music_directory | wc -l)
  fixedMenu=1
  menuNumber=1
  if [[ "$2" == "BROWSE MENU" ]]; then
    fixedMenu=2
    menuNumber=2
  fi
  pages=$((($artists + $menuNumber) /7))
  if [ $((($artists + $menuNumber) % 7)) -gt 0 ]; then
    let pages++
  fi
  currPage=$((($1-1)/7 +1))
  typeLen=$(echo "$2" | wc -m)
  typePadding=$((78 / 2 +  $typeLen / 2))
  clear
  echo "┌───────────────────────────────────────────────────────────────────────────────┐"
  echo "│                                 MUSIC  EDITOR                                 │"
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  printf "│%*s%*s│\n" "$typePadding" "$2" $((78-$typePadding+1)) " "
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  echo "│             Select artist using the arrow keys, then press enter.             │"
  echo "│                                                                               │"
  if [[ $currPage -eq 1 ]]; then
    if [[ "$1" == "1" ]]; then
      echo -e "│   \033[101m¬ Back\033[0m                                                                      │"
    else
      echo "│   ¬ Back                                                                      │"
    fi
    if [[ $fixedMenu -eq 2 ]]; then
      if [[ "$1" == "2" ]]; then
        echo -e "│   \033[101m¬ New artist\033[0m                                                                │"
      else
        echo "│   ¬ New artist                                                                │"
      fi
    fi
    readFromLine=1
  else
    menuNumber=$((($currPage -1) * 7))
    readFromLine=$((($currPage -1) * 7 - $fixedMenu + 1))
  fi

  artists=$(ls $music_directory | sed -n "$readFromLine,$(($currPage*7 -$fixedMenu))p" | tr " " "=")
	for artist in $artists; do
	  let menuNumber++
		nameArtist=$(echo $artist | tr "=" " ")
    if [[ "$1" == "$menuNumber" ]]; then
      printf "│   \033[101m¬ %-70s\033[0m    │\n" "$nameArtist"
    else
      printf "│   ¬ %-70s    │\n" "$nameArtist"
    fi
	done
  printf "│                                      %3s/%-3s                                  │\n" "$currPage" "$pages"
  echo "└───────────────────────────────────────────────────────────────────────────────┘"
}

function printAlbumMenu() {
  # $1 = selected menu
  # $2 = type of menu
  # $3 = artist name
  fixedMenu=2
  menuNumber=2
  if [[ "$2" == "ADD COVER MENU" ]]; then
    fixedMenu=1
    menuNumber=1
  fi
  # Calculate selected page
  albums=$(ls $music_directory/"$3" | wc -l)
  pages=$((($albums+2) /7))
  if [ $((($albums + 2) % 7)) -gt 0 ]; then
    let pages++
  fi
  currPage=$((($1-1)/7 +1))
  artistLen=$(echo "$3" | wc -m)
  typeLen=$(echo "$2" | wc -m)
  artPadding=$((78 / 2 + $artistLen / 2))
  typePadding=$((78 / 2 +  $typeLen / 2))
  clear
  echo "┌───────────────────────────────────────────────────────────────────────────────┐"
  echo "│                                 MUSIC  EDITOR                                 │"
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  printf "│%*s%*s│\n" "$typePadding" "$2" $((78-$typePadding+1)) " "
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  printf "│%*s%*s│\n" "$artPadding" "$3" $((78-$artPadding+1)) " "
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  echo "│              Select album using the arrow keys, then press enter.             │"
  echo "│                                                                               │"

  if [[ $currPage -eq 1 ]]; then
    if [[ "$1" == "1" ]]; then
      echo -e "│   \033[101m¬ Back\033[0m                                                                      │"
    else
      echo "│   ¬ Back                                                                      │"
    fi
    if [[ $fixedMenu -eq 2 ]]; then
      if [[ "$2" == "BROWSE MENU" ]]; then
        if [[ "$1" == "2" ]]; then
          echo -e "│   \033[101m¬ New album\033[0m                                                                 │"
        else
          echo "│   ¬ New album                                                                 │"
        fi
      else
        if [[ "$1" == "2" ]]; then
          echo -e "│   \033[101m¬ All\033[0m                                                                       │"
        else
          echo "│   ¬ All                                                                       │"
        fi
      fi
    fi
    readFromLine=1
  else
    menuNumber=$((($currPage-1)*7))
    readFromLine=$(($menuNumber -1))
  fi

  albums=$(ls $music_directory/"$3" | sed -n "$(($readFromLine)),$(($currPage*7 +1))p" | tr " " "=")
	for album in $albums; do
	  let menuNumber++
    if [ $menuNumber -gt $((7*$currPage)) ]; then
      break
    fi
		nameAlbum=$(echo $album | tr "=" " ")
    if [[ "$1" == "$menuNumber" ]]; then
      printf "│   \033[101m¬ %-70s\033[0m    │\n" "$nameAlbum"
    else
      printf "│   ¬ %-70s    │\n" "$nameAlbum"
    fi
	done

  printf "│                                      %3s/%-3s                                  │\n" "$currPage" "$pages"
  echo "└───────────────────────────────────────────────────────────────────────────────┘"
}

function printSongMenu() {
  # $1 = selected menu
  # $2 = type of menu
  # $3 = artist name
  # $4 = album name
  # Calculate selected page
  songs=$(ls $music_directory/"$3"/"$4" | wc -l)
  pages=$((($songs+2) /7))
  if [ $((($songs + 2) % 7)) -gt 0 ]; then
    let pages++
  fi
  currPage=$((($1-1)/7 +1))
  artistAlbumLen=$(echo "$3: $4" | wc -m)
  typeLen=$(echo "$2" | wc -m)
  artPadding=$((78 / 2 + $artistAlbumLen / 2))
  typePadding=$((78 / 2 +  $typeLen / 2))
  clear
  echo "┌───────────────────────────────────────────────────────────────────────────────┐"
  echo "│                                 MUSIC  EDITOR                                 │"
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  printf "│%*s%*s│\n" "$typePadding" "$2" $((78-$typePadding+1)) " "
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  printf "│%*s%*s│\n" "$artPadding" "$3: $4" $((78-$artPadding+1)) " "
  echo "├───────────────────────────────────────────────────────────────────────────────┤"
  echo "│              Select song using the arrow keys, then press enter.              │"
  echo "│                                                                               │"

  if [[ $currPage -eq 1 ]]; then
    if [[ "$1" == "1" ]]; then
      echo -e "│   \033[101m¬ Back\033[0m                                                                      │"
    else
      echo "│   ¬ Back                                                                      │"
    fi
    if [[ "$2" == "BROWSE MENU" ]]; then
      if [[ "$1" == "2" ]]; then
        echo -e "│   \033[101m¬ New song\033[0m                                                                  │"
      else
        echo "│   ¬ New song                                                                  │"
      fi
    else
      if [[ "$1" == "2" ]]; then
        echo -e "│   \033[101m¬ All\033[0m                                                                       │"
      else
        echo "│   ¬ All                                                                       │"
      fi
    fi
    menuNumber=2
    readFromLine=1
  else
    menuNumber=$((($currPage-1)*7))
    readFromLine=$(($menuNumber -1))
  fi

  songs=$(ls $music_directory/"$3"/"$4"  | sed -n "$(($readFromLine)),$(($currPage*7 +1))p" | tr " " "=")
	for song in $songs; do
	  let menuNumber++
    if [ $menuNumber -gt $((7*$currPage)) ]; then
      break
    fi
		nameSong=$(echo $song | tr "=" " ")
    if [[ "$1" == "$menuNumber" ]]; then
      #BUG: │   ¬ 08 - Breathe No More (Live From Le Zénith,France_2004).mp3               │ 1 space from correct position
      printf "│   \033[101m¬ %-74s\033[0m│\n" "$nameSong"
    else
      printf "│   ¬ %-74s│\n" "$nameSong"
    fi
	done

  printf "│                                      %3s/%-3s                                  │\n" "$currPage" "$pages"
  echo "└───────────────────────────────────────────────────────────────────────────────┘"
}
############################################

################################################################

# --new -n artistName new artist DONE | --artist -t artistName change artist name | --album -b directory albumname DONE|
# --mobile -m [Ip] sent to mobile DONE | --download -d https:... artistName albumName songName DONE |
# --help display help window | # Options errors # Fast rename option


# Start with no arguments go to menu
if [ $# -eq 0 ]; then
  mainMenu
  exit 0
fi


options=$1
shift

case $options in
"--new"|"-n")
	if ! [ $# -eq 1 ]; then usage; fi
	new "$1"
	notificationFinish
	;;
"--rename")
	if ! [ $# -eq 0 ]; then usage; fi
	renameAll
	notificationFinish
	;;
"--artist"|"-a")
	if [ $# -gt 2 ]; then usage; fi
	changeArtist "$1" "$2"
	notificationFinish
	;;
"--album"|"-b")
	if ! [ $# -eq 2 ]; then usage; fi
	changeAlbum "$1" "$2"
	notificationFinish
	;;
"--download"|"-d")
	if ! [ $# -eq 4 ]; then usage; fi
	download "$1" "$2" "$3" "$4"
	;;
"--mobile"|"-m")
	if [ $# -gt 1 ]; then usage; fi
	send $1
	;;
"--help"|"-h")
	if [ $# -gt 0 ]; then usage; fi
	help
	;;
*)
	echo Error
	;;
esac

exit 0
