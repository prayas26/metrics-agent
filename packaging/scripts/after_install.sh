#!/bin/bash
set -e

INIT_DIR=/opt/digitalocean/scripts
SVC_NAME=node-collector

if command -v systemctl 2> /dev/null; then
        echo "Configue systemd..."
        ln -s ${INIT_DIR}/${SVC_NAME}.service /etc/systemd/system/${SVC_NAME}.service
        systemctl daemon-reload
        systemctl enable --now ${SVC_NAME}.service
elif command -v initctl 2> /dev/null; then
        echo "Configue upstart..."
        ln -s ${INIT_DIR}/${SVC_NAME}.conf /etc/init/${SVC_NAME}.conf
        initctl reload-configuration
        initctl start ${SVC_NAME}
else
        echo "Unknown init system. Exiting..." > /dev/stderr
        exit 1
fi
