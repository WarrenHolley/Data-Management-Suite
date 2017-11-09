# SecureZip
# Author	Warren Holley
# Version 	0.1.0
# Date		October 20, 2017	

# Purpose	Intended to compress folders containing many small files (Images, Books, Music)
#		to increase simplicity of filing and integrity verification.

# CALL		szip [Directory]*
#		Compresses files within [Directory].
#		Regex Compatible

# REQUIREMENTS	md5deep, a component of 'hashdeep'.
#		   All Distro-repositories carry this program.
#		   https://github.com/jessek/hashdeep/

#!/bin/bash

# Check for correct number of arguments, inform user of usage.
if [ "$#" == "0" ]; then
	echo " Usage: \`szip.sh [Directory]*\`"
	echo "  [Directory] is Regex Compatible"
	exit
fi

HomeDirectory=`pwd`
for i
do
	#Parse relative paths to full, remove trailing '/' for .zip naming. 
	RelPath="$i"
	if ! [ "${i::1}" == "/" ]; then
		if [ "${RelPath:0:2}" == "./" ]; then
			RelPath="${RelPath:2}" #Takes off ./ from pathing if needed
		fi		
		FullPath="$HomeDirectory/$RelPath"
	else
		FullPath="$RelPath"
	fi

	#Remove trailing '/' From Path if needed
	if [ "${FullPath: -1}" == "/" ]; then
		FullPath="${FullPath::-1}"
	fi
	
	#Path is now non-relative. Does not have trailing '/'

	#Skip if non-folder. This program designed for compression of folders for bulk archival.
	#May implement at later date.
	if ! [ -d "$FullPath" ]; then
		continue
	fi

	#Compress folder
	#Expressed in this method as others have resulted in access errors thrown.
	cd "$FullPath"
	zip -rq "$FullPath".zip ./*
	cd "$HomeDirectory"

	#Unzip into temporary folder
	ExtractionFolderName=`mktemp -d /tmp/ExtractionFolder.temp.XXXXXXXXXX`
	unzip -q "$FullPath".zip -d $ExtractionFolderName

	#Calculate & Compare Checksums: Memory-Intensive. May adjust to file-based if needed.
	InputChecksum=`md5deep -rb -j0 "$FullPath"/*`
	OutputChecksum=`md5deep -rb -j0 "$ExtractionFolderName"/*`

	if [ "$InputChecksum" == "$OutputChecksum" ]; then
		echo "Compressed: "$RelPath
	else
		echo "Err or Mismatch - Deleting " $RelPath
		rm "$FullPath".zip
	fi
	
	#Cleanup temporary folder
	rm -r "$ExtractionFolderName"
done
