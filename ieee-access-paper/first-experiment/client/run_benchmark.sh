#!/bin/bash

# Log destination folder
DESTINATION=./logs/test/

# Benchmark parameters
INITIAL_CONCURRENCY=1;
FINAL_CONCURRENCY=1001;
STEP=25
ROUNDS=10;
TIME_INTERVAL=60;
REQUESTS=100000
HOST=127.0.0.1;
PORT=8081;
PAGE=index1.html

# Create destination folder
mkdir -p $DESTINATION;

# Loop varying concurrent conections
for CONCURRENCY in $(seq $INITIAL_CONCURRENCY $STEP $FINAL_CONCURRENCY); do

	# Loop varying test round
	for ROUND in $(seq $ROUNDS); do

		# Start energy measuring
		# Use your command here

		# Test run
		ab -n $REQUESTS -c $CONCURRENCY http://$HOST:$PORT/$PAGE > $DESTINATION/ab-out-$CONCURRENCY-$ROUND.txt

		# Stop energy measuring
		# Use your command here

		# Intervalo entre uma rodada e outra
		sleep $TIME_INTERVAL
		
		
	done

	CONCURRENCY=$((CONCURRENCY+STEP));

done

