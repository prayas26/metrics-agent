#!/bin/sh
# IMPORTANT: rpm will execute with /bin/sh.
# DO NOT change this and make sure you are linting with shellcheck to ensure
# compatbility with scripts
set -ue

SVC_NAME=node-collector
SYSTEMD_SCRIPT_FILE=/etc/systemd/system/${SVC_NAME}.service

NOBODY_USER=nobody
NOBODY_GROUP=nogroup

# fedora uses nobody instead of nogroup
getent group nobody 2> /dev/null \
        && NOBODY_GROUP=nobody

main() {
        update_selinux

        if command -v systemctl >/dev/null 2>&1; then
                init_systemd
        elif command -v initctl >/dev/null 2>&1; then
                init_upstart
        else
                echo "Unknown init system. Exiting..." > /dev/stderr
                exit 1
        fi
}


update_selinux() {
        echo "Detecting SELinux"
        enforced=$(getenforce 2>/dev/null || echo)

        if [ "$enforced" != "Enforcing" ]; then
                echo "SELinux not enforced"
                return
        fi

        setsebool -P nis_enabled 1 || echo "Failed" > /dev/stderr
}

init_systemd() {
        echo "${SYSTEMD_SCRIPT}" | tee ${SYSTEMD_SCRIPT_FILE}
        # cannot symlink to /etc/systemd/system because of an old bug
        # https://bugzilla.redhat.com/show_bug.cgi?id=955379
        # enable --now is unsupported on older versions of debian/systemd
        systemctl enable ${SYSTEMD_SCRIPT_FILE}
        systemctl stop ${SVC_NAME} || true
        systemctl start ${SVC_NAME}
        systemctl status ${SVC_NAME}
}

init_upstart() {
        echo "${UPSTART_SCRIPT}" | tee /etc/init/${SVC_NAME}.conf
        initctl reload-configuration
        initctl stop ${SVC_NAME} || true
        initctl start ${SVC_NAME}
        initctl status ${SVC_NAME}
}


SYSTEMD_SCRIPT=$(cat <<-END
[Unit]
Description=DigitalOcean node_collector agent
After=network-online.target
Wants=network-online.target

[Service]
User=${NOBODY_USER}
Group=${NOBODY_GROUP}
ExecStart=/usr/local/bin/node_collector
Restart=always

OOMScoreAdjust=-900
SyslogIdentifier=DigitalOceanAgent
PrivateTmp=yes
ProtectSystem=full
ProtectHome=yes
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
END
)

UPSTART_SCRIPT=$(cat <<-END
# node_collector - An agent that collects system metrics.
#
# An agent that collects system metrics and transmits them to DigitalOcean.
description "The DigitalOcean Monitoring Agent"
author "DigitalOcean"

start on runlevel [2345]
stop on runlevel [!2345]
console none
normal exit 0 TERM
kill timeout 5
respawn

script
  exec su -s /bin/sh -c 'exec "\$0" "\$@"' ${NOBODY_USER} -- /usr/local/bin/node_collector --syslog
end script
END
)


main
