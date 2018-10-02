#!/bin/bash
set -e

SVC_NAME=node-collector

if command -v systemctl 2> /dev/null; then
        echo "Configue systemd..."
        systemctl disable --now ${SVC_NAME}.service || true
        unlink /etc/systemd/system/${SVC_NAME}.service || true
        systemctl daemon-reload || true
elif command -v initctl 2> /dev/null; then
        echo "Configue upstart..."
        initctl stop ${SVC_NAME} || true
        unlink /etc/init/${SVC_NAME}.conf || true
        initctl reload-configuration || true
else
        echo "Unknown init system" > /dev/stderr
fi
