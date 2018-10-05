#!/bin/sh
# IMPORTANT: rpm will execute with /bin/sh.
# DO NOT change this and make sure you are linting with shellcheck to ensure
# compatbility with scripts
set -uxe

APP_ROOT=/opt/digitalocean/node_collector
SCRIPT_DIR=$APP_ROOT/scripts
SVC_NAME=node-collector

main() {
        if command -v systemctl >/dev/null 2>&1; then
                # cannot symlink to /etc/systemd/system because of an old bug
                # https://bugzilla.redhat.com/show_bug.cgi?id=955379
                # enable --now is unsupported on older versions of debian/systemd
                systemctl enable ${SCRIPT_DIR}/${SVC_NAME}.service
                systemctl stop ${SVC_NAME} || true
                systemctl start ${SVC_NAME}
                systemctl status ${SVC_NAME}
        elif command -v initctl >/dev/null 2>&1; then
                ln -s ${SCRIPT_DIR}/${SVC_NAME}.conf /etc/init/${SVC_NAME}.conf
                initctl reload-configuration
                initctl stop ${SVC_NAME} || true
                initctl start ${SVC_NAME}
                initctl status ${SVC_NAME}
        else
                echo "Unknown init system. Exiting..." > /dev/stderr
                exit 1
        fi
}

main
