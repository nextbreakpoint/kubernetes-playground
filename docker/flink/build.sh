!#/bin/sh

docker build -t 192.168.1.11:30000/nextbreakpoint/flink:1.7.2 --build-arg flink_version=1.7.2 --build-arg scala_version=2.11 .
