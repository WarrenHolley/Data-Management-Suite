#!/bin/bash

# FileChecksum.sh
# Description	Experimental SFV Implementation.
# Author	Warren Holley
# Version	0.1.0
# Date		Mar 1, 2018

# Purpose	Part of the Bulk Data Management Suite
#		Depending on flags set, can, to file names:
#		 Calculate, then append the file's CRC32 checksum,
#		 Run through and check checksums,
#		 Remove checksums
#		 Compare checksums and alarm user if mismatch (corruption/changes)
#		Designed for archival of files in a system where files move around.
#		 Where file-stored checksums may break upon movement. (Eg md5sum/hashDeep)
#		Corrects the issue of many file-stored checksum archival systems
#		 as they do not like directory (and occasionally sorting) changes.

# Notes		This program is just an SFV variant, though is easily modifiable to use
#		 cryptographic or other hash functions.
#		This is an experimental system written by a junior developer.
#		 This -SHOULD NOT- be used in a production environment or non-backed up system.

# Known Issues	0.1.0: Finding/adding checksum step works on the last '.' in the Filename.
#			Incompatible with multi-step filestypes (.tar.gz). 

# CALL		FileChecksum.sh [-Rqvaux] [File or Folder]*
#		 For each argument file or folder:
#		 Adds or overwrites CRC32 checksum within the file, or for each file in the folder.
#		 Regex compatible

# FLAGS: 
# -R		Recursive. Steps through each folder in argument list

# -q		Quiet. Do not push any information to StdOut. Mutex with -v. 
#		 Off Default: Push relevant information to StdOut. (Eg: name changes, modifications)
#		  Still pushes important error info to StdErr.
# -v		Verbose. Inform user for each file verified, or other minor action taken.
#		 Off Default: Alarm user only on incorrect file checksum through stderr.
# -h		Print the usage page.

# -a		Add. Add checksums to files without one.

# -x		Delete. Delete checksums. (Both Volatile and CRC32)
# -u		Update. Updates checksums that are incorrect. 
#		 (ONLY RECOMMENDED AFTER KNOWING WHAT FILES ARE TO BE UPDATED)

# -F		Fast Mode. Don't compare files with checksums. Only add or delete.
# -V		Volatile: Adds volatile ([*]) checksum to all files without a checksum. 

# -S		Space. When adding, add a space preceding the checksum   (F.A -> F [x].A)
#			When removing, scrub excess spaces immediately preceding the checksum.
# -P		Period. When adding, add a period preceding the checksum (F.A -> F.[x].A)
#			When removing, scrub excess periods immediately preceding the checksum.
#		 Default neither: append immediately 	    (F.A -> F[x].A)


# Planned Flags:


# -U		Hard Update. Replaces all volatile checksums ([*]) with standard CRC32 checksums
# -Q		Hard Quiet. Don't push any info to StdOut or StdErr.

#---------------------------------------------------
#----------------FUNCTIONS--------------------------
#---------------------------------------------------
# HexCheck $1
#  Check string argument for hexadecimal.
#  Echoes 'true' if input argument is in hexadecimal
#  Otherwise, Echoes 'false'
function hexCheck {
	valid='0-9a-fA-F'
	if [[ ! $1 =~ [^$valid] ]]; then
		echo "true"
		return
	fi
	echo "false"
}
#-----------------------------------------
function errPrint { #Only print if Quiet flag not set.
	#if ! [ "$hardQuietFlag" == "true" ]; then
		>&2 echo -e "$1"
	#fi
}
#-----------------------------------------
function verbosePrint { #Only print if Verbose Flag Set
	if [ "$verboseFlag" == "true" ]; then
		echo -e "$1"
	fi
}
#-----------------------------------------
function stdPrint { #Print to StdOut if Quiet Flag not set.
	if ! [ "$quietFlag" == "true" ]; then
		echo -e "$1"
	fi
}
#------------------------------------------------------
# Informs user on how to use this program. TODO: UPDATE
function printUsage {
echo "FileChecksum.sh [-Rqvaux] [File or Folder]*"
echo " An SVF Implementation"
echo " For each argument file or folder:"
echo " Compare, Add or Update CRC32 checksum within each file's name."
echo " Regex compatible. Recursive compatible"
echo ""
echo " FLAGS: "
echo " -h  Print this page."
echo " -R  Recursive. Steps through each folder in argument list"
echo " -q  Quiet. Do not push any information to StdOut or StdErr. Mutex with -v"
echo "      Off Default: Push incorrect checksum info to StdErr."
echo " -v  Verbose. Inform user for each file correct, or action taken. Mutex with -q"
echo "      Off Default: Alarm user only on incorrect file checksum through stderr."
echo " -a  Add checksums to files without one."
echo " -u  Updates checksums that are incorrect."
echo " -x  Delete checksums. (Both Volatile and CRC32)"
}
#-------------------------------------------------------------------------------------

# getNameChecksum
#  In file name in arg $1, echo the checksum (without brackets) if found.
#  Do not echo if not found, do not calculate checksum. Just output first set found.
#   Output: Echo 8*hexchar, '*', or nothing.
#   E.g: a[12345678] -> "12345678" (Without quotation)
function getNameChecksum {
for ((i=${#1}; i>=0; i--))
do
	#Break: Moving from filename to foldername
	if [ "${1:i:1}" == "/" ]; then
		break
	#Check for sq. brackets in appropriate places
	elif ! [ "${1:i:1}" == "[" ]; then
		continue
	elif ! [ "${1:i+9:1}" == "]" ] && ! [ "${1:i+2:1}" == "]" ]; then
		continue
	fi

	#Catch volatile "[*]" flag
	if [ "${1:i:3}" == "[*]" ] ; then
		echo "*"
		return
	fi
	#Otherwise, check for std hex checksum
	isHex=$(hexCheck ${1:i+1:8})
	if [ "$isHex" == "true" ]; then
		echo "${1:i+1:8}"
		return
	fi	
done
echo "" #Default case. Echos "null"
}

#--------------------------------------------------------------------------------------

# getNameIndex
#  From file name in $1, echo the zero-index of the opening sq. bracket of the checksum.
#  If nothing found, echo "-1"
#   E.g.: ab[12345678]
#    echoes "2" (Without quotation)
function getNameIndex {
for ((i=${#1}; i>=0; i--))
do
	#Break: Moving from filename to foldername
	if [ "${1:i:1}" == "/" ]; then
		break
	#Check for sq. brackets in appropriate places
	elif ! [ "${1:i:1}" == "[" ]; then
		continue
	elif ! [ "${1:i+9:1}" == "]" ] && ! [ "${1:i+2:1}" == "]" ]; then #TODO: global length var.
		continue
	fi

	#Catch volatile "[*]" flag
	if [ "${1:i:3}" == "[*]" ]; then
		echo "$i"
		return	
	fi 
	#Otherwise, check for std hex checksum
	isHex=$(hexCheck "${1:i+1:8}")
	if [ "$isHex" == "true" ]; then
		echo "$i"
		return
	fi
done
echo "-1" #Default case. No checksum found.
}

#--------------------------------------------------------------------------------------

# addNameChecksum
#  Adds Checksum in $2 to filename in $1
#  $1 must exist, not have checksum.
#  Places checksum, bound in sq. brackets, behind the first '.' found.
#   Placed normally behind the filetype.
#   If added to hidden file without extention, prepend a '.' as to keep the file hidden.
#   If added to file without extention, append checksum to the file.


function addNameChecksum {
localFileName="$1"
localChecksum="$2"

# Find index of file name extention.
for ((fi=${#localFileName}; fi>=0; fi--)) 
do
	if [ "${localFileName:fi:1}" == "." ]; then 
		break
	fi
done

#Surround with square brackets.
localChecksum="[$localChecksum]"

# If Space Flag, and not a hidden file, prepend " "
if [ "$spaceFlag" == "true" ] && ! [ "$fi" == "0" ]; then
	localChecksum=" $localChecksum"
fi

#If Period Flag, or hidden file, prepend '.'
if [ "$periodFlag" == "true" ] || [ "$fi" == "0" ]; then 
	localChecksum=".$localChecksum"
fi

#If File has no filetype, append checksum
if [ "$fi" == "-1" ]; then 
	fi=${#localFileName} 
fi

#Finally, add checksum to filename.
mv "$localFileName" "${localFileName::fi}$localChecksum${localFileName:fi}"

}

#---------------------------------------------------------------------------------
# removeNameChecksum
#  Remove checksum from the filename of arg $1, inc. sq. brackets.
#  Return-echos the new name of the file. (For use in Update)
function removeNameChecksum {
index=$(getNameIndex "$1") #Fetch index of checksum
if [ "$index" == "-1" ]; then #If DNE, return.
	return
#If it's a Volatile flag, length=3
elif [ "${1:index:3}" == "[*]" ]; then
	endIndex=$index+3
else #Default, length=10. (TODO: global-length var)
	endIndex=$index+10
fi

#Also remove prepended spaces or periods if needed.
#Upgrade to loop? Single-test unlikely to scrub a whole filename, and using 
#both spaces and periods in file-organziational schema is rare.
if [ "$periodFlag" == "true" ] && [ "${1:index-1:1}" == "." ]; then
	index=$index-1
fi
if [ "$spaceFlag" == "true" ] && [ "${1:index-1:1}" == " " ]; then
	index=$index-1
fi 

mv "$1" "${1:0:index}${1:endIndex}" #Rename file
echo "${1:0:index}${1:endIndex}" #Return name of new file.
}

#-----------------------------------------------------------------------------

#FLAGS:
# -R - Recurse
# -v - Verbose
# -q - Quiet
# -a - Add checksums if needed
# -x - Delete Checksums
# -u - Update incorrect
# -S - Add/Remove Spaces
# -P - Add/Remove Periods

#DEBUG:
recurseFlag="false"

verboseFlag="false"
quietFlag="false"

addFlag="false"
deleteFlag="false"
updateFlag="false"

fastFlag="false"
volatileFlag="false"

spaceFlag="false"
periodFlag="false"


#------------------------
#------  SETUP  ---------
#------------------------
# Catch flags:
# Encounted a weird range of bugs when working with 'getopts', so brute forcing flag collection here.
for ((i=0;i<=$#;i++)) 
do	
	#If flag, parse; otherwise, continue.
	if [ "${!i:0:1}" == "-" ]; then
		#Unimplemented: Catch args with sub-args, then continue.
		
		#Otherwise, single arg. Case switch to catch multi-set args (-abc)
		argArray="${!i:1}"
		while ! [ "$argArray" == "" ]; do
			case "${argArray:0:1}" in
			"R") recurseFlag="true" ;;
			"v") verboseFlag="true" ;;
			"q") quietFlag="true" ;;
			"a") addFlag="true" ;;
			"x") deleteFlag="true" ;;
			"u") updateFlag="true" ;;
			"F") fastFlag="true";;
			"V") volatileFlag="true";;
			"S") spaceFlag="true";;
			"P") periodFlag="true";;
			"h") printUsage ; exit ;;
			*) echo "Unknown flag: '${argArray:0:1}'";
				echo "Printing Help Page" ; echo "";
				printUsage; exit;;
			esac
			argArray="${argArray:1}"
		done
	fi	
done


#Make sure there are no conflicting flags:
if [ "$verboseFlag" == "true" ] && [ "$quietFlag" == "true" ]; then
	echo "Flag Mutex Error:"
	echo " Both the Quiet and Verbose flags Set. Exiting."
	exit #Not -sure- if needed, as 
fi
if [ "$addFlag" == "true" ] && [ "$deleteFlag" == "true" ]; then
	echo "Flag Mutex Error:"
	echo " Both Add and Delete flags are Set."
	echo " If you want to reinitialize checksums, Add+Update is recommended"
	echo "  or two seperate executions of Delete, then Add."
	echo " Running -ax is not recommended. Exiting."
	exit
fi
if [ "$deleteFlag" == "true" ] && [ "$updateFlag" == "true" ]; then
	echo "Flag Mutex Error:"
	echo " Both Delete and Update flags are on."
	echo " These have mutually exclusive effects."
	echo " Exiting."	
	exit
fi
if [ "$volatileFlag" == "true" ] && [ "$addFlag" == "true" ]; then
	echo "Flag Mutex Error:"
	echo " Both Volatile and Add/Delete flags are on."
	echo " These have mutually exclusive effects."
	echo " Exiting."	
	exit
fi 

if [ "$spaceFlag" == "true" ] && [ "$periodFlag" == "true" ] && [ "$addFlag" == "true" ]; then
	echo "Flag Mutex Error:"
	echo " Both Space and Flag flags are on alongside Add."
	echo " Would prepend both to each checksum."
	echo " Exiting."	
	exit
fi  

#Setup Flags to include upon recursion. (TODO: Clean up.)
recurseFlags="-R" #Automatic
if [ "$verboseFlag" == "true" ]; then
	recurseFlags="$recurseFlags"v
fi
if [ "$quietFlag" == "true" ]; then
	recurseFlags="$recurseFlags"q
fi
if [ "$addFlag" == "true" ]; then
	recurseFlags="$recurseFlags"a
fi
if [ "$deleteFlag" == "true" ]; then
	recurseFlags="$recurseFlags"x
fi
if [ "$updateFlag" == "true" ]; then
	recurseFlags="$recurseFlags"u
fi
if [ "$fastFlag" == "true" ]; then
	recurseFlags="$recurseFlags"F
fi
if [ "$volatileFlag" == "true" ]; then
	recurseFlags="$recurseFlags"V
fi 
if [ "$spaceFlag" == "true" ]; then
	recurseFlags="$recurseFlags"S
fi 
if [ "$periodFlag" == "true" ]; then
	recurseFlags="$recurseFlags"P
fi 


#----------------------------------
#------------  MAIN  --------------
#----------------------------------
#For each Argument:
for ((i=1;i<=$#;i++))
do
	#Clear last loop's variables
	fileNameChecksum=""
	fileDataChecksum=""
	
	#If flag, with argument, skip both.
	if [ "${!i}" == "-X" ]; then #Unimplemented Prototype - Add || tests as needed
		i=$((i+1))
		continue
	#If single flag (no arg), skip.
	elif [ "${!i:0:1}" == "-" ]; then
		continue
	#If folder and recurse flag, recurse.
	elif [ -d "${!i}" ] && [ "$recurseFlag" == "true" ]; then
		recurseArg="${!i}"
		# Remove trailing '/' for clairity, consistancy.
		if [ "${recurseArg: -1}" == "/" ]; then
			recurseArg="${!i::-1}"
		fi
		# Recurse for all files/directories in the folder.
		"$0" $recurseFlags "$recurseArg"/*
		continue
	#If folder, without recurse Flag
	elif [ -d "${!i}" ]; then
		verbosePrint "Folder - Not Recursing - ${!i}"
		continue
	#If file DNE, alarm, skip.
	elif ! [ -f "${!i}" ]; then
		errPrint "! File DNE: ${!i}"
		continue
	fi 

	#At this point, ${!i} is guarenteed to be a file, thus
	fileName="${!i}"
	
	#If Deleteing Checksums, do so.
	if [ "$deleteFlag" == "true" ]; then	
		updatedName=(`removeNameChecksum "$fileName"`)
		if ! [ "$updatedName" == "" ]; then
			stdPrint "Removed Checksum - $updatedName"
		else
			verbosePrint "Nothing Removed  - $fileName"
		fi
		continue
	fi

	#Fetch checksum from Name
	fileNameChecksum=`getNameChecksum "$fileName"`
	
	#If no checksum, add if Add flag set.
	if [ "$fileNameChecksum" == "" ] && [ "$addFlag" == "true" ]; then
		fileDataChecksum=`crc32 "$fileName"` #Calculate Checksum
		fileDataChecksum=${fileDataChecksum:0:8} #Truncate
		addNameChecksum "$fileName" "$fileDataChecksum"
		stdPrint "Added Checksum - $fileName"
		continue
	#If no checksum, add volatile if Volatile flag set.
	elif [ "$fileNameChecksum" == "" ] && [ "$volatileFlag" == "true" ]; then
		addNameChecksum "$fileName" "*"
		stdPrint "Added Volatile - $fileName"
		continue
	#No checksum, but do not add:
	elif [ "$fileNameChecksum" == "" ]; then
		verbosePrint "No Checksum - $fileName"
		continue
	#If volatile flag, alarm user, continue	
	elif [ "$fileNameChecksum" == "*" ]; then
		verbosePrint "Volatile - ${!i}"
		continue
	fi 

	#Calculate File Checksum if not in 'Fast' mode.
	if [ "$fastFlag" == "true" ]; then
		continue
	elif [ "$fileDataChecksum" == "" ]; then #If hasn't been calculated yet.
		fileDataChecksum=`crc32 "$fileName"` #Calculate Checksum
		fileDataChecksum=${fileDataChecksum:0:8} #Truncate
	fi

	#Compare remembered and calculated checksums	
	# If equal, good. Continue
	if [ "${fileNameChecksum,,}" == "${fileDataChecksum,,}" ]; then #${i,,} == toLower(i);
		verbosePrint "GOOD - $fileName"
	# If unequal, has Update Flag set, update.
	elif [ "$updateFlag" == "true" ]; then
		updatedName=(`removeNameChecksum "$fileName"`)
		addNameChecksum "$updatedName" "$fileDataChecksum"
		stdPrint "UPDATE $fileName"
		stdPrint " $fileNameChecksum -> $fileDataChecksum"
	# Otherwise, alarm user.
	else #Checksum Mismatch, update False
		errPrint "!BAD - $fileName"
		errPrint " $fileNameChecksum != $fileDataChecksum"
	fi
	
done
