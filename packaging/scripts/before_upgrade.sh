#!/bin/bash
set -e

SVC_NAME=node-collector

if command -v systemctl 2> /dev/null; then
        systemctl stop ${SVC_NAME}.service || true
elif command -v initctl 2> /dev/null; then
        initctl stop ${SVC_NAME} || true
else
        echo "Unknown init system" > /dev/stderr
fi
