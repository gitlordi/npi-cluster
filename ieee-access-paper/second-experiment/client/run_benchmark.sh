#!/bin/bash

# Log destination folder
DESTINATION=./logs/test/

# Benchmark parameters
INITIAL_CONCURRENCY=8;
FINAL_CONCURRENCY=488;
STEP=24
ROUNDS=10;
TIME_INTERVAL=60;
TIME=10m;
LOGFILE=wiki-pages.siege

# Create destination folder
mkdir -p $DESTINATION;

# Loop varying concurrent conections
for CONCURRENCY in $(seq $INITIAL_CONCURRENCY $STEP $FINAL_CONCURRENCY); do

	# Loop varying test round
	for ROUND in $(seq $ROUNDS); do

		# Start energy measuring
		# Use your command here

		# Test run
		siege -c $CONCURRENCY -b -t $TIME -f $LOGFILE &> $DESTINO/siege-out-$CONCORRENCIA-$RODADA.txt

		# Stop energy measuring
		# Use your command here

		# Intervalo entre uma rodada e outra
		sleep $TIME_INTERVAL
		
		
	done

	CONCURRENCY=$((CONCURRENCY+STEP));

done

