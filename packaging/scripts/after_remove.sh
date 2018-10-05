#!/bin/sh
# IMPORTANT: rpm will execute with /bin/sh.
# DO NOT change this and make sure you are linting with shellcheck to ensure
# compatbility with scripts
set -uxe

SVC_NAME=node-collector

if command -v systemctl >/dev/null 2>&1; then
        echo "Configure systemd..."
        systemctl stop ${SVC_NAME} || true
        systemctl disable ${SVC_NAME}.service || true
        unlink /etc/systemd/system/${SVC_NAME}.service || true
        systemctl daemon-reload || true
elif command -v initctl >/dev/null 2>&1; then
        echo "Configure upstart..."
        initctl stop ${SVC_NAME} || true
        unlink /etc/init/${SVC_NAME}.conf || true
        initctl reload-configuration || true
else
        echo "Unknown init system" > /dev/stderr
fi
