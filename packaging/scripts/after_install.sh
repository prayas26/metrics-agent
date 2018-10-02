#!/bin/bash
set -e

INIT_DIR=/opt/digitalocean/scripts
SVC_NAME=node-collector

if command -v systemctl 2> /dev/null; then
        echo "Configue systemd..."
        # cannot symlink to /etc/systemd/system because of an old bug
        # https://bugzilla.redhat.com/show_bug.cgi?id=955379
        # enable --now is unsupported on older versions of debian/systemd
        systemctl enable ${INIT_DIR}/${SVC_NAME}.service
        systemctl start ${SVC_NAME}
        systemctl status ${SVC_NAME}
elif command -v initctl 2> /dev/null; then
        echo "Configue upstart..."
        ln -s ${INIT_DIR}/${SVC_NAME}.conf /etc/init/${SVC_NAME}.conf
        initctl reload-configuration
        initctl start ${SVC_NAME}
else
        echo "Unknown init system. Exiting..." > /dev/stderr
        exit 1
fi
