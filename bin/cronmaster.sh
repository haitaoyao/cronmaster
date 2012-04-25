#!/bin/bash
##################################################################
# 
# written by haitao.yao @ 2011-07-18.10:46:36
# 
# used to manage the crontabs
# 
##################################################################
current_dir="$(cd $(dirname $0);pwd)"

export CRONMASTER_HOME=$current_dir/../
CRONMASTER_PID_FILE=$CRONMASTER_HOME/master.pid
#nohup python cronmaster-server.py >> $CRONMASTER_HOME/logs/access.log  2>&1 &
#python cronmaster-server.py

if [ ! -d "$CRONMASTER_HOME/logs" ]
then
	mkdir $CRONMASTER_HOME/logs
fi

# check the server connection
check_server_connection()
{
	server_pid=$1
	if [ -z "$server_pid" ]
	then
		echo "no server pid"
		exit 1
	fi
	server_address=$(netstat -tlnp 2>/dev/null|grep "$server_pid"|awk '{print $4}')
	if [ -z "$server_address" ]
	then
		echo "failed to ping server, address: $server_address"
		exit 1
	fi
		
	wget -q "$server_address/ok.html" -O /dev/null
	if [ "$?" -ne '0' ]
	then
		echo "failed to ping server, address: $server_address"
		exit 1
	else
		echo "server ping success, address: $server_address"
	fi

}

# start the master server
start_master_server()
{
	if [ -f $CRONMASTER_PID_FILE ]
	then
		old_pid=$(cat $CRONMASTER_PID_FILE)
	fi
	if [ -n "$old_pid" ]
	then
		old_process=$(ps -ef|grep python|grep 'cronmaster-server.py'|grep $old_pid)
		if [ -n "$old_process" ]
		then
			echo "master server is running now, pid: $old_pid, address: $(netstat -tlnp 2>/dev/null|grep $old_pid|awk '{print $4}')"
			exit 1
		fi
	fi
	nohup python $current_dir/cronmaster-server.py >> $CRONMASTER_HOME/logs/access.log  2>&1 &
	server_pid=$!
	echo $server_pid > $CRONMASTER_PID_FILE
	sleep 1
	check_server_connection $server_pid
	echo "cronmaster server started at: $server_address, pid: $server_pid"
}


# stop the master server
stop_master_server()
{
	if [ -f $CRONMASTER_PID_FILE ]
	then
		old_pid=$(cat $CRONMASTER_PID_FILE)
	fi
	if [ -n "$old_pid" ]
	then
		old_process=$(ps -ef|grep python|grep 'cronmaster-server.py'|grep $old_pid)
		if [ -n "$old_process" ]
		then
			kill -9 $old_pid
			echo "master server killed, pid: $old_pid"
			exit 0
		fi
	fi
	echo "No master server running"
	exit 1
}

# restart the master server
restart_master_server()
{
	if [ -f $CRONMASTER_PID_FILE ]
	then
		old_pid=$(cat $CRONMASTER_PID_FILE)
	fi
	if [ -n "$old_pid" ]
	then
		old_process=$(ps -ef|grep python|grep 'cronmaster-server.py'|grep $old_pid)
		if [ -n "$old_process" ]
		then
			kill -9 $old_pid
			echo "old master server: $old_pid killed"
		else
			echo "no master server is running now"
		fi
	fi
	start_master_server	
}

# check the status of the master server
status_master_server()
{
	if [ -f $CRONMASTER_PID_FILE ]
	then
		old_pid=$(cat $CRONMASTER_PID_FILE)
	fi
	if [ -n "$old_pid" ]
	then
		old_process=$(ps -ef|grep python|grep 'cronmaster-server.py'|grep $old_pid)
		if [ -n "$old_process" ]
		then
			echo "master server is running, pid: $old_pid"
			echo "connection status: $(netstat -tlnp 2>/dev/null|grep $old_pid)"
			check_server_connection $old_pid
			exit 0
		fi
	fi
	echo "no master server running"
	
}

print_help()
{
	echo 
	echo "cronmaster script"
	echo "Usage: $0 start|stop|status|restart"
	printf "\tstart\t start the server\n"
	printf "\tstop\t stop the master server\n"
	printf "\tstatus\t check the status of the master server\n"
	printf "\trestart\t restart the master server\n"
	echo
}

if [ -z "$1" ]
then
	print_help
	exit 1
fi

case "$1" in
	start)
		start_master_server
		;;
	stop)
		stop_master_server
		;;
	status)
		status_master_server
		;;
	restart)
		restart_master_server
		;;
esac


