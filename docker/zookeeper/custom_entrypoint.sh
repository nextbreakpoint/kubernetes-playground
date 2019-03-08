#!/bin/sh

set -e

# Allow the container to be started with `--user`
if [[ "$1" = 'zkServer.sh' && "$(id -u)" = '0' ]]; then
    chown -R "$ZOO_USER" "$ZOO_DATA_DIR" "$ZOO_DATA_LOG_DIR" "$ZOO_CONF_DIR"
    exec su-exec "$ZOO_USER" "$0" "$@"
fi

# Generate the config only if it doesn't exist
if [[ ! -f "$ZOO_CONF_DIR/zoo.cfg" ]]; then
    CONFIG="$ZOO_CONF_DIR/zoo.cfg"

    echo "clientPort=$ZOO_PORT" >> "$CONFIG"
    echo "dataDir=$ZOO_DATA_DIR" >> "$CONFIG"
    echo "dataLogDir=$ZOO_DATA_LOG_DIR" >> "$CONFIG"

    echo "tickTime=$ZOO_TICK_TIME" >> "$CONFIG"
    echo "initLimit=$ZOO_INIT_LIMIT" >> "$CONFIG"
    echo "syncLimit=$ZOO_SYNC_LIMIT" >> "$CONFIG"

    echo "maxClientCnxns=$ZOO_MAX_CLIENT_CNXNS" >> "$CONFIG"

    echo "autopurge.snapRetainCount=5" >> "$CONFIG"
    echo "autopurge.purgeInterval=1" >> "$CONFIG"

    for server in $ZOO_SERVERS; do
        echo "$server" >> "$CONFIG"
    done
fi

# Write myid only if it doesn't exist
if [[ ! -f "$ZOO_DATA_DIR/myid" ]]; then
    echo "${ZOO_MY_ID:-1}" > "$ZOO_DATA_DIR/myid"
fi

export SERVER_JVMFLAGS="-javaagent:/opt/jmx-exporter/jmx-exporter.jar=7070:/etc/jmx-exporter/zookeeper.yml"

if [ -z "$JAAS_CONFIG_LOCATION" ]; then
  if [ -n "$JAAS_CONFIG_CONTENT" ]; then
    echo $JAAS_CONFIG_CONTENT | base64 -d > "$ZOO_CONF_DIR/server_jaas.conf"
    JAAS_CONFIG_LOCATION="$ZOO_CONF_DIR/server_jaas.conf"
  fi
fi

if [ -n "$JAAS_CONFIG_LOCATION" ]; then
  export SERVER_JVMFLAGS="$SERVER_JVMFLAGS -Djava.security.auth.login.config=$JAAS_CONFIG_LOCATION"
  echo "quorum.auth.enableSasl=true" >> "$CONFIG"
  echo "quorum.auth.learnerRequireSasl=true" >> "$CONFIG"
  echo "quorum.auth.serverRequireSasl=true" >> "$CONFIG"
  echo "quorum.auth.learner.loginContext=QuorumLearner" >> "$CONFIG"
  echo "quorum.auth.server.loginContext=QuorumServer" >> "$CONFIG"
  echo "quorum.cnxn.threads.size=20" >> "$CONFIG"
  echo "authProvider.1=org.apache.zookeeper.server.auth.SASLAuthenticationProvider" >> "$CONFIG"
  echo "requireClientAuthScheme=sasl" >> "$CONFIG"
fi

exec "$@"
