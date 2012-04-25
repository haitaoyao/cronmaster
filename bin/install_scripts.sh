#!/bin/bash
##################################################################
# 
# written by haitao.yao @ 2011-07-20.15:20:56
# 
# used to install the script into repository 
# 
##################################################################
current_dir="$(cd $(dirname $0);pwd)"
export CRONMASTER_HOME=$current_dir/../

# print the help information
print_help()
{
	echo
	echo " This is used to install the crontab script into repository"
	echo "Usage: $0 -f script_file -n script_name -o"
	printf "\t-f\t script file path. script file should be archived into a tar.gz file as gzip format\n"
	printf "\t-n\t script name. this is used to identify the crontab task\n"
	printf "\t-o\t if the script exits, override the existing script. Without this option, the installation process will fail\n"
	echo
}

if [ -z "$1" ]
then
	print_help
	exit 1
fi

while getopts ':f:n:o' OPT
do
	case $OPT in
		f)
			script_file=$OPTARG
			;;
		n)	
			script_name=$OPTARG
			;;
		o)
			override_script='1'
			;;
		?)
			print_help
			exit 0;
			;;
		:)
			print_help
			exit 1
			;;
	esac
done

if [ -z "$script_file" -o ! -f "$script_file" ]
then
	echo "script file should not be empty"
	print_help
	exit 1
fi
if [ -z "$(file $script_file -b |grep gzip)" ]
then
        echo "$script_file is not a gzip file, can't accept other file type"
        exit 1
fi 


if [ -z "$script_name" ]
then
	echo "script_name should no be empty"
	print_help
	exit 1
fi
cronmaster_config_file=$CRONMASTER_HOME/config/cronmaster.conf
if [ ! -f "$cronmaster_config_file" ]
then
	echo "no config file for config master"
	exit 1
fi

cronmaster_script_location=$(cat $cronmaster_config_file|grep 'scripts='|awk -F 'scripts=' '{print $2}')
if [ -z "$cronmaster_script_location" ]
then
	echo "script config in $cronmaster_config_file"
	exit 1
fi
if [ ! -d $cronmaster_script_location ]
then
	echo "$cronmaster_script_location is not a dir"
	exit 1
fi

installed_script_file=$cronmaster_script_location/$script_name.tar.gz
if [ -f "$installed_script_file" ]
then
	echo "script file $install_script_file exists!"
	if [ -z "$override_script" ]
	then
		echo "If want to override the file , use -o option"
		exit 1
	fi
	rm $installed_script_file
fi

cp $script_file $installed_script_file
script_file_md5=$(md5sum $script_file |awk '{print $1}')
echo "$script_file_md5" > $installed_script_file.md5
echo "$script_file installed, md5: $script_file_md5"

