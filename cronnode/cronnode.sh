#!/bin/bash
##################################################################
# 
# written by haitao.yao @ 2011-07-18.11:02:25
# 
# used to manage the crontab tasks for the local machine
# 
##################################################################
current_dir="$(cd $(dirname $0);pwd)"

# configue the cron node
# all your configurations, write here!
configure_cronnode()
{
	# url for the CRONMASTER api
	CRONMASTER_URL='http://10.130.137.19:9100'
	
	# dir for the crontab tasks
	CRONNODE_PLUGIN_DIR=/tmp/cronnode

	#log folder for cronnode
	CRONNODE_LOG_DIR=""

	# log reservation duration, unit: day, default: 10 days
	# the expired log files will be deleted
	CRONNODE_LOG_RESERVE_DAY='10'

	CRONNODE_TMP_DIR="/tmp/cronnode"
	if [ ! -d $CRONNODE_PLUGIN_DIR ]
	then
		mkdir -p $CRONNODE_PLUGIN_DIR
	fi
	
	
	if [ -z "$CRONNODE_LOG_DIR" ]
	then
		# default log dir is: $CNODE_HOME/logs
		CRONNODE_LOG_DIR=/tmp
	fi
	
	if [ ! -d "$CRONNODE_LOG_DIR" ]
	then
		mkdir -p $CRONNODE_LOG_DIR
	fi

	if [ -z "$CRONNODE_TMP_DIR" ]
	then
		CRONNODE_TMP_DIR=/tmp
	fi
	CRONNODE_TMP_DIR=$CRONNODE_TMP_DIR/$(date +%Y%m%d%H%M%S.%s)
	if [ ! -d "$CRONNODE_TMP_DIR" ]
	then
		mkdir -p $CRONNODE_TMP_DIR
	fi
}

# log for the cronnode
cronnode_log()
{
	while getopts "l:m:" OPT
	do
		case $OPT in
			l)
				LOG_LEVEL=$OPTARG
				;;
			m)
				LOG_MSG=$OPTARG
				;;
			:)
				LOG_LEVEL="INFO"
				;;
		esac
	done
	if [ -z "$LOG_MSG" ]
	then
		return 1
	fi
	if [ -z "$LOG_LEVEL" ]
	then
		LOG_LEVEL=INFO
	fi
	date_string=$(date +%Y-%m-%d-%H:%M:%S)
	printf  "CRONNODE_LOG $LOG_LEVEL $date_string $LOG_MSG\n"
	printf  "CRONNODE_LOG $LOG_LEVEL $date_string $LOG_MSG\n" >> $CRONNODE_LOG_DIR/cronnode.$(date +%Y%m%d).log
}

# clear the expired logs of the cronnode
clear_cronnode_logs()
{
	# run only when mid-night
	if [ "$(date +%H)" -gt 0 ]
	then
		return 0
	fi
	if [ -z "$CRONNODE_LOG_RESERVE_DAY" ]
	then
		CRONNODE_LOG_RESERVE_DAY=10
	fi
	max_log_date=$(date +%Y%m%d -d "${CRONNODE_LOG_RESERVE_DAY} days ago")
	cd $CRONNODE_LOG_DIR
	for log_file in $(ls cronnode.*.log)
	do
		log_date=$(echo $log_file|awk -F '.' '{print $2}')
		if [ "$max_log_date" -gt "$log_date" ]
		then
			rm $log_file
		fi
	done
	cd $current_dir
}

get_tmp_file_name()
{
	echo "$CRONNODE_TMP_DIR/cronnode.tmp.$(date +%Y%m%d%H%M%S.%s)"	
}

rm_tmp_file()
{
	if [ -f "$1" -a "x$(dirname $1)" == x"$CRONNODE_TMP_DIR" ]
	then
		rm $1
	fi
}

report_to_master()
{
	if [ -z "$1" ]
	then
		return 1
	fi
	curl -s -d "message=$1" $CRONMASTER_URL/report >> /dev/null 
	return $?
}

CRONTAB_FILE='/var/spool/cron/root'
# add the crontab tasks
add_crontab()
{
	script_name=$1
	is_new_script=$2
	if [ -z "$script_name"  -o ! -d $CRONNODE_PLUGIN_DIR/$script_name ]
	then
		return 1
	fi
	if [ ! -f "$CRONTAB_FILE" ]
	then
		MSG="No crontab file as: $CRONTAB_FILE"
		cronnode_log -l 'ERROR' -m "$MSG"
		report_to_master "$MSG"
		return 1
	fi
	script_cron_config=$CRONNODE_PLUGIN_DIR/$script_name/crontab.conf
	if [ ! -f $script_cron_config ]
	then
		cronnode_log -l 'ERROR' -m "no crontab config file as $script_cron_config"
		return 1
	fi
	script_cron_expression=$(cat $script_cron_config|grep 'crontab.expression='|awk -F 'crontab.expression=' '{print $2}')
	replaced_path=$(echo $CRONNODE_PLUGIN_DIR/$script_name|sed 's/\//\\\//g')
	script_cron_command=$(cat $script_cron_config|grep 'crontab.command='|awk -F 'crontab.command=' '{print $2}'|sed "s/\$CRONTAB_HOME/$replaced_path/g")
	if [ -z "$script_cron_expression" ]
	then
		cronnode_log -l 'ERROR' -m "no crontab expression in file : $script_cron_config, file content: $(cat $script_cron_config)"
		return 1
	fi
	if [ -z "$script_cron_command" ]
	then
		cronnode_log -l 'ERROR' -m "no crontab command in file : $script_cron_config, file content: $(cat $script_cron_config)"
		return 1
	fi
	replaced_command=$(echo $script_cron_command|sed 's/\//\\\//g')
	sed -i "/.*$replaced_path.*/d" $CRONTAB_FILE
	echo "$script_cron_expression $script_cron_command" >> $CRONTAB_FILE
	if [ "$is_new_script" -eq 1 ]
	then
		report_to_master "$script_name added, expression: $script_cron_expression , command: $script_cron_command" &
	else
		report_to_master "$script_name upgraded, expression: $script_cron_expression , command: $script_cron_command" &
	fi
}


#download the script from the master
download_script()
{
	cron_script_name=$1
	if [ -z "$1" ]
	then
		cronnode_log -l 'ERROR' -m'no arguments'
		return 1
	fi
	wget -q -o /dev/null $CRONMASTER_URL/scripts/$cron_script_name -O $CRONNODE_TMP_DIR/$cron_script_name
	if [ "$?" -ne 0 ]
	then
		cronnode_log -l 'ERROR' -m"Failed to download $cron_script_name from $CRONMASTER_URL/scripts/$cron_script_name"
		return 1
	fi
	if [ "$(tar tf $CRONNODE_TMP_DIR/$cron_script_name |grep -c -E '^crontab.conf') " -ne 1 ]
	then
		cronnode_log -l "ERROR" -m"no crontab.conf in $cron_script_name"
		rm $CRONNODE_TMP_DIR/$cron_script_name
		return 1
	fi
	wget -q -o /dev/null  $CRONMASTER_URL/scripts/$cron_script_name.md5 -O $CRONNODE_TMP_DIR/$cron_script_name.md5
	if [ "$?" -ne 0 ]
	then
		MSG="Failed to download $cron_script_name.md5 from $CRONMASTER_URL/scripts/$cron_script_name.md5"
		cronnode_log -l 'ERROR' -m "$MSG"
		report_to_master "$MSG"
		rm $CRONNODE_TMP_DIR/$cron_script_name
		return 1
	fi
	script_name=$(echo $cron_script_name|awk -F '.tar.gz' '{print $1}')
	if [ -f "$CRONNODE_PLUGIN_DIR/$script_name.md5" ]
	then
		if [ x"$(cat $CRONNODE_PLUGIN_DIR/$script_name.md5)" == x"$(cat $CRONNODE_TMP_DIR/$cron_script_name.md5)" ]
		then
			MSG="$script_name is not upgraded, skip"
			report_to_master "$MSG"
			cronnode_log -l "INFO" -m "$MSG"
			return 1
		fi
	fi
	is_new_script=1
	if [ -d "$CRONNODE_PLUGIN_DIR/$script_name" ]
	then
		rm -rf $CRONNODE_PLUGIN_DIR/$script_name
		is_new_script="0"
	fi
	mkdir $CRONNODE_PLUGIN_DIR/$script_name
	tar zxf $CRONNODE_TMP_DIR/$cron_script_name -C $CRONNODE_PLUGIN_DIR/$script_name
	mv $CRONNODE_TMP_DIR/$cron_script_name.md5 $CRONNODE_PLUGIN_DIR/$script_name.md5
	if [ "$is_new_script" -eq "1" ]
	then
		cronnode_log -l "INFO" -m "$script_name installed"
	else
		cronnode_log -l "INFO" -m "$script_name upgraded"
	fi
	add_crontab $script_name $is_new_script
}

# upgrade the crontabs
upgrade_cron()
{
	tmp_file_name=$(get_tmp_file_name)
	wget -q  "$CRONMASTER_URL/list" -O $tmp_file_name
	if [ "$?" -ne 0 ]
	then
		MSG="failed to get list from $CRONMASTER_URL"
		report_to_master "$MSG"
		cronnode_log -l 'ERROR' -m "$MSG"
		return 1
	fi

	for script_name in $(cat $tmp_file_name)
	do
		download_script $script_name	
	done
	rm_tmp_file $tmp_file_name
}


configure_cronnode



upgrade_cron
exit_code=$?

rm -rf $CRONNODE_TMP_DIR
clear_cronnode_logs
exit $exit_code
