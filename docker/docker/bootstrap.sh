#!/bin/bash

set -e

until psql -h irods-db -U postgres -c '\l' > /dev/null 2>&1; do
  echo "Postgres is unavailable - sleeping"
  sleep 1
done

# Get the irods_avu_json-ruleset package
if [[ ! -d /irods_avu_json-ruleset ]]; then
    git clone https://github.com/MaastrichtUniversity/irods_avu_json-ruleset.git /irods_avu_json-ruleset
fi

# Install the python ruleset
cp /irods_avu_json-ruleset/rules/core.py /etc/irods/core.py

# Install the python dependencies
pip install -r /irods_avu_json-ruleset/requirements.txt

# Build microservices
mkdir -p /irods_avu_json-ruleset/microservices/build && \
    cd /irods_avu_json-ruleset/microservices/build && \
    cmake ../ && \
    make && \
    make install

# Check if this is a first run of this container
if [[ ! -e /var/run/irods_installed ]]; then

    if [ -n "$RODS_PASSWORD" ]; then
        echo "Setting irods password"
        sed -i "23s/.*/$RODS_PASSWORD/" /etc/irods/setup_responses
    fi

    # set up the iCAT database
    /opt/irods/setupdb.sh /etc/irods/setup_responses

    # set up iRODS
    python /var/lib/irods/scripts/setup_irods.py < /etc/irods/setup_responses

    # Add python rule engine to iRODS
    /opt/irods/add_rule_engine.py /etc/irods/server_config.json python 1

    touch /var/run/irods_installed

else
    service irods start
fi

# this script must end with a persistent foreground process 
tail -F /var/lib/irods/log/rodsLog.* /var/lib/irods/log/reLog.*
