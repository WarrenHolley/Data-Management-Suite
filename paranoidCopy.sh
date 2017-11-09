# paranoidCopy - Copy File with Post-Copy Checksum
# Author	Warren Holley
# Version 	0.1.0
# Date		October 20, 2017	

# Purpose	Securely copy a file. Extends the CoreUtils 'cp' function
#		RSync is recommended for larger batches, as it is
#		far more mature. Mostly done as a proof-of-concept to add
#		to the suite.

# CALL		scp [Source] [Target]
#		Securely copy file/folder from [Source] to [Target]
#		Regex Incompatible

#!/bin/bash

# Check for correct number of arguments.
if ! [ "$#" == "2" ]; then
	echo " Usage: scp [Source] [Target]"
	echo "  Securely copy file/folder from [Source] to [Target]:"
	echo "  Regex Incompatible"
	exit
fi

# Define
Source=$1
Target=$2

if [ -d "$Source" ]; then
	# Remove trailing '/' for clairity.
	if [ "${Source: -1}" == "/" ]; then
		Source="${Source::-1}"
	fi
	
	# Create Target folder if does not exist.
	if ! [ -d "$Target" ]; then
		mkdir "$Target"
	fi

	# Recurse, for each item in the folder.
	# Bypasses a quirk of cp that if run twice, incorrectly 
	#  copies Source folder into Target folder on second run.
	for j in "$Source"/*
	do
		"$0" "$j" "$Target${j:${#Source}}"
	done

elif ! [ -f "$Source" ]; then	# Break if file does not exist.
	echo "Source Invalid  $Source"
	exit
else	
	cp -a "$Source" "$Target" #Default (File, exists): Copy.
fi

# Calculate, compare checksums of Source and Target files.
#  Excessive, as runs in each level of recursion. 
#  May add recurse-flag so that only the first layer runs the check.
SourceChecksum=`md5deep -rb -j0 "$Source"`
TargetChecksum=`md5deep -rb -j0 "$Target"`

if [ "${SourceChecksum:0:32}" == "${TargetChecksum:0:32}" ]; then
	echo "Copied: "$Target
else
	echo "Err or Mismatch - Deleting " $Target
	rm -rf "$Target"
fi




