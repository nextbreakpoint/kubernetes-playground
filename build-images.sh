#!/bin/bash

pushd docker/zookeeper

./build.sh

popd

pushd docker/kafka

./build.sh

popd

pushd docker/flink

./build.sh

popd
