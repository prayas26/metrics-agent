#!/bin/bash
set -e

SVC_NAME=node-collector

if command -v systemctl 2> /dev/null; then
        systemctl daemon-reload
        systemctl restart ${SVC_NAME}.service || true
elif command -v initctl 2> /dev/null; then
        initctl restart ${SVC_NAME} || true
else
        echo "Unknown init system" > /dev/stderr
fi
