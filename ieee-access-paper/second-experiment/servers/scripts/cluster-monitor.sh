#!/bin/bash

# State detection counters
SOFT_LIMIT_MAX_COUNT=6;
HARD_LIMIT_MAX_COUNT=3;
LOW_LIMIT_MAX_COUNT=2;

SOFT_COUNT=0;
HARD_COUNT=0;
LOW_COUNT=0;

# Misc options
SLEEP_INTERVAL=5;
TIME_TO_BECOME_AVAILABLE=25;
VERBOSE=0;
TEST=0;
MAX_NODES=7;
online_hosts_count=7;

# GPIO map
node_map=(0 25 11 8 3 2 4)

#########################################################################

function GetOptions(){
	local PARAMS;
	while getopts "hTvS:H:c:C:l:t:d:L:n:g:o:" PARAMS; do
		case "$PARAMS" in
			h) PrintHelp;
				 exit;
				 ;;
			T) TEST=1;
				 ;;
			v) VERBOSE=1;
				 ;;
			S) SOFT_LIMIT=$OPTARG;
				 ;;
			H) HARD_LIMIT=$OPTARG;
				 ;;
			c) SOFT_LIMIT_MAX_COUNT=$OPTARG;
				 ;;
			C) HARD_LIMIT_MAX_COUNT=$OPTARG;
				 ;;
			l) LOW_LIMIT_MAX_COUNT=$OPTARG;
				 ;;
			t) SLEEP_INTERVAL=$OPTARG;
				 ;;
			o) online_hosts_count=$OPTARG;
				 ;;
			?) echo "Invalid option.";
				 exit;
				 ;;
		esac
	done
}

function GetConnections(){
	echo $1;
	local data;
	exec 3< /dev/tcp/$1/65000;
	data=$(cat <&3);
	exec 3<&-;
	current=$(echo $data|cut -d ' ' -f 1);
	if [ -z "$current" ] ; then
		date;
		exit;
	fi
	average=$(echo $data|cut -d ' ' -f 2);
	max=$(echo $data|cut -d ' ' -f 3);
	((CURRENT_QUEUE+=current));
	AVERAGE_QUEUE=$((AVERAGE_QUEUE+average));
	MAX_QUEUE=$((MAX_QUEUE+max));

	if [ "$VERBOSE" -eq 1 ]; then
		echo "$1: $current connections; Ideal: $average; Max:  $max";
    echo "Accumulated: $CURRENT_QUEUE connections; Ideal: $AVERAGE_QUEUE; Max: $MAX_QUEUE";
	fi
}

function CheckLimits(){
  local state;
  local count;
  if [ $CURRENT_QUEUE -gt $MAX_QUEUE ]; then
    ((HARD_COUNT++));
    ((SOFT_COUNT++));
    LOW_COUNT=0;
    state="CRITICAL"
    count=$HARD_COUNT;
  elif [ $CURRENT_QUEUE -gt $AVERAGE_QUEUE ]; then
    ((SOFT_COUNT++));
    HARD_COUNT=0;
    LOW_COUNT=0;
    state="OVERLOADED"
    count=$SOFT_COUNT;
  elif [ $CURRENT_QUEUE -lt $((AVERAGE_QUEUE-average)) ]; then
		HARD_COUNT=0;
		SOFT_COUNT=0;
    ((LOW_COUNT++));
    state="UNDERUTILIZED"
    count=$LOW_COUNT;
	else
		HARD_COUNT=0;
    SOFT_COUNT=0;
    LOW_COUNT=0;
		state="NORMAL";
		count=0;
  fi

  if [ $HARD_COUNT -ge $HARD_LIMIT_MAX_COUNT ] || [ $SOFT_COUNT -ge $SOFT_LIMIT_MAX_COUNT ]; then
    activate_node=1;
  elif [ $LOW_COUNT -ge $LOW_LIMIT_MAX_COUNT ]; then
    activate_node=-1;
	else
		activate_node=0;
  fi

  if [ "$VERBOSE" -eq 1 ]; then
    echo "Status: $state - cont: $count";
    echo "";
  fi
}

function ResetCounters(){
	HARD_COUNT=-1;
	SOFT_COUNT=-1;
	LOW_COUNT=-1;
}


function PrepareGPIO(){
  local j;
	for j in 7 8 25 11 9 2 3 4 14 15; do
		echo $j > /sys/class/gpio/export 2> cluster_monitor.log
	done
  echo out > /sys/class/gpio/gpio$1/direction
}

function StartNewNode(){
  local gpio_number=${node_map[$online_hosts_count]};
	PrepareGPIO "$gpio_number";
	echo 1 > /sys/class/gpio/gpio$gpio_number/value
	ResetCounters;
	((online_hosts_count++));
  local not_available=1;
  until [ $not_available -eq 0 ]; do
    curl http://192.168.2.10$online_hosts_count/index0.html;
    not_available=$?;
    sleep $SLEEP_INTERVAL;
  done
	if [ "$VERBOSE" -eq 1 ]; then
		echo $gpio_number;
		echo "##########################################################################"
		echo "Cluster overloaded. Activating a new node. Online hosts: $online_hosts_count...";
		echo "##########################################################################"
	fi;
}

function StopANode(){
	ssh root@rpi2$online_hosts_count -- shutdown -h now
  sleep $SLEEP_INTERVAL;
  local gpio_number=${node_map[$online_hosts_count-1]};
  PrepareGPIO "$gpio_number";
  echo 0 > /sys/class/gpio/gpio$gpio_number/value
  ((online_hosts_count--));
  sleep 2;
  ResetCounters;
  if [ "$VERBOSE" -eq 1 ]; then
    echo "##########################################################################"
    echo "Cluster Underutilizes. Deactivating a node. Online hosts: $online_hosts_count...";
    echo "##########################################################################"
  fi;

}

function CoreLoop(){
	local i;
	while true; do

		AVERAGE_QUEUE=0;
		MAX_QUEUE=0;
		CURRENT_QUEUE=0;

		for i in `seq 2 $online_hosts_count`; do
			GetConnections "rpi2$i";
		done

		CheckLimits;

		if [ $online_hosts_count -lt $MAX_NODES ] && [ $activate_node -gt 0 ]; then
			if [ $TEST -eq 0 ]; then
				StartNewNode;
			else
				echo "Should start a node!";
			fi
		elif [ $online_hosts_count -gt 2 ] && [ $activate_node -lt 0 ]; then
			if [ $TEST -eq 0 ]; then
				StopANode;
			else
				echo "Should stop a node!";
			fi
		fi

		sleep $SLEEP_INTERVAL;

	done
}


# Start here

GetOptions $@;

CoreLoop;

exit 0;
