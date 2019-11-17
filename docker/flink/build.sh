#!/bin/sh

docker build -t 192.168.1.11:30000/nextbreakpoint/flink:1.9.0 --build-arg flink_version=1.9.0 --build-arg scala_version=2.11 .
