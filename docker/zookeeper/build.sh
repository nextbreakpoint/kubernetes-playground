!#/bin/sh

docker build -t 192.168.1.11:30000/nextbreakpoint/zookeeper:3.4.12 --build-arg zookeeper_version=3.4.12 .
