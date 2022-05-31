#!/bin/sh

docker build -t 192.168.56.11:30000/nextbreakpoint/cp-kafka:5.3.1 --build-arg cp_kafka_version=5.3.1 .
