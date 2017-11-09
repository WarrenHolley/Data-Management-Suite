# fcksum - File-stored Checksum
# Author	Warren Holley
# Version 	0.1.0
# Date		October 19, 2017	

# Purpose	Check the pointed File for corruption or error, by storing the checksum in the 
#		 Filename. Extends the linux CRC32 utility.
#		Stores the information at the end of the Filename, before the Filetype.
#		Intended for data archival, where files may be moved around. Most file-stored
#		 checksums do not like directory or sorting changes.

# Notes		This program is just an SFV variant, though is easily modifiable to use
#		 cryptographic or other hash functions.
#		Can flag files that have changing/volatile data by replacing the checksum with a *
#		 E.g.: file[----].zip -> file[*].zip
#		 This will skip the file.

# Known Issues	0.1.0: Finding/adding checksum step works on the last '.' in the Filename.
#			Incompatible with multi-step filestypes (.tar.gz). 

# CALL		filecksum [File or Folder]*
#		Compares CRC32 in Filename to calculated checksum. Informs user if not equal.
#		If no Filename checksum, adds to the filename before the Filetype.
#		Regex compatible

#!/bin/bash

# Check for minimum number of arguments.
if [ "$#" == "0" ]; then
	echo " Usage: fcksum [File*]"
	echo "  Compares CRC32 in Filename to calculated checksum. Informs user if not equal."
	echo "  If no Filename checksum, adds to the filename before the Filetype."
	echo "  Regex compatible"
	exit
fi

# Loop for each argument (No flags)
for i
do
	if [ -d "$i" ]; then
		# Remove trailing '/' for clairity, consistancy.
		if [ "${i: -1}" == "/" ]; then
			i="${i::-1}"
		fi
		# Recurse for each file/directory in the folder.
		for j in "$i"/*
		do
			"$0" "$j"
		done
		continue
	elif ! [ -f "$i" ]; then	#Else: skip if .
		echo "DNE:             $i"
		continue
	fi

	# Calculate Checksum
	CalcChecksum=`crc32 "$i"`
	ChecksumLength=8	#Checksum Length, in characters.
	CalcChecksum=${CalcChecksum:0:$ChecksumLength} 

	# Attempt to find Filename checksum
	for (( n=${#i}-1; n>= 0; n--)); do
		if [ "${i:n:1}" == "]" ] ; then
			if [ "${i:n-2:3}" == "[*]" ] ; then
				FileChecksum="[*]"
			else
				FilenameChecksum="${i:n-8:8}"
			fi
			break
		fi
	done
	
	# Skip file if flagged with a Volatile [*]
	if [ "$FileChecksum" == "[*]" ]; then
		echo "SKIP:            $i"
		continue
	fi
	
	# If File does not have Name-checksum, add it before the last '.', the filetype.
	#  Known bug: Messes with multi-step names (.tar.gz)
	if [ "$FilenameChecksum" == "" ]; then
		AddingChecksum="True"
		echo "Adding CRC32 to  $i"
		for (( n=${#i}-1; n>= 0; n--)); do
			if [ "${i:n:1}" == "." ] ; then
				mv "$i" "${i:0:n}[$CalcChecksum]${i:n}"
				FilenameChecksum=$CalcChecksum
				break
			fi
		done
	fi
	# If no filetype, just append the checksum.
	if [ "$FilenameChecksum" == "" ]; then
		mv "$i" "${i}[$CalcChecksum]"
		FilenameChecksum=$CalcChecksum
	fi

	# If no checksum appended, compare checksums, let user know results.
	if [ "$CalcChecksum" == "$FilenameChecksum" ] && ! [ "$AddingChecksum" == "True" ]; then
		echo "OK:   $CalcChecksum   $i"
	elif ! [ "$AddingChecksum" == "True" ]; then
		echo "FAIL: $CalcChecksum   $i"
	fi
done

