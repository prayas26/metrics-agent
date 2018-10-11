#!/bin/bash
#
# Author: Brett Jones <blockloop>
# Purpose: Provide simple UAT tasks for creating/updating/deleting droplets
# configured with node-collector. To add another method to this script simply
# create a new function called 'function command_<task>'. It will automatically
# get picked up as a new command.

set -ue

# team context in the URL of the browser
CONTEXT=14661f
OS=$(uname | tr '[:upper:]' '[:lower:]')
TAG=node-collector-test-${USER}
SUPPORTED_IMAGES="centos-6-x32 centos-6-x64 centos-7-x64 debian-8-x32 debian-8-x64 \
        debian-9-x64 fedora-27-x64 fedora-28-x64 ubuntu-14-04-x32 ubuntu-14-04-x64 \
        ubuntu-16-04-x32 ubuntu-16-04-x64 ubuntu-18-04-x64"

JONES_SSH_FINGERPRINT="a1:bc:00:38:56:1f:d2:b1:8e:0d:4f:9c:f0:dd:66:6d"
THOR_SSH_FINGERPRINT="c6:c6:01:e8:71:0a:58:02:2c:b3:e5:95:0e:b1:46:06"
EVAN_SSH_FINGERPRINT="b9:40:22:bd:fb:d8:fa:fa:4e:11:d9:8e:58:e9:41:73"
SNYDER_SSH_FINGERPRINT="47:31:9b:8b:87:a7:2d:26:79:17:87:83:53:65:d4:b4"

# disabling literan '\n' error in shellcheck since that is the expected behavior
# shellcheck disable=SC1117
USER_DATA_DEB="#!/bin/bash\n apt-get update && apt-get install -y curl; curl -s https://packagecloud.io/install/repositories/digitalocean-insights/node-collector/script.deb.sh | sudo bash\n apt install -y node-collector"
# shellcheck disable=SC1117
USER_DATA_RPM="#!/bin/bash\n curl -s https://packagecloud.io/install/repositories/digitalocean-insights/node-collector/script.rpm.sh | sudo bash\n yum install -y node-collector"


function main() {
        [ -z "${AUTH_TOKEN}" ] \
                && abort "AUTH_TOKEN is not set"

        cmd=$1
        shift
        fn=command_$cmd
        # disable requirement to quote 'fn' which would break this code
        # shellcheck disable=SC2086
        if [ "$(type -t ${fn})" = function ]; then
                ${fn} "$*"
        else
                usage
                exit 1
        fi
}

function command_help() {
        usage
}

function usage() {
        commands=$(grep -P '^function command_' "$0" \
                | sed 's,function command_,,g' \
                | sed 's,() {,,g' \
                | sort \
                | xargs)

        echo
        echo "Usage: $0 [$commands]"
        echo
}

# delete all droplets tagged with $TAG
function command_delete_all() {
        confirm "Are you sure you want to delete all droplets with the tag ${TAG}?" \
                || (echo "Aborted" && return 1)

        echo "Deleting..."
        request DELETE "/droplets?tag_name=$TAG" \
                | jq .
}

# list all droplet IP addresses tagged with $TAG
function command_list_ips() {
        list | jq -r '.droplets[].networks.v4[] | select(.type=="public") | .ip_address'
}

# list all droplet IDs tagged with $TAG
function command_list_ids() {
        list | jq -r '.droplets[].id'
}

# list all droplets with all of their formatted metadata
function command_list() {
        list | jq .
}

function command_browse() {
        launch "https://cloud.digitalocean.com/tags/$TAG?i=${CONTEXT}"
}

# open all droplets in the browser
function command_open_all() {
        urls=$(command_list_ids | xargs -n1 -I{} echo https://cloud.digitalocean.com/droplets/{}/graphs?i=${CONTEXT} | tee /dev/stderr)
        if confirm "Open these urls?"; then
                for u in $urls; do
                        launch "$u"
                done
        else
                echo "Aborting"
        fi
}

# create a droplet for every SUPPORTED_IMAGE and automatically install node-collector
# using either apt or yum
function command_create_all() {
        for i in $SUPPORTED_IMAGES; do
                create_image "$i" &
        done
        wait

        if confirm "Open the tag list page?"; then
                launch "https://cloud.digitalocean.com/tags/$TAG?i=${CONTEXT}"
        fi
}

# ssh to all droplets and run <init system> status node-collector to verify
# that it is indeed running
function command_status_all() {
        command_exec_all "if command -v systemctl 2&>/dev/null; then \
                systemctl is-active node-collector; \
        else \
                initctl status node-collector; \
        fi"
}

# ssh to all droplets and run yum/apt update to upgrade to the latest published
# version of node-collector
function command_update_all() {
        command_exec_all "if command -v yum 2&>/dev/null; then \
                yum check-update >/dev/null; \
                yum update node-collector; \
        else \
                apt-get update >/dev/null; \
                apt-get install --only-upgrade node-collector; \
        fi"
}

# ssh to all droplets and execute a command
function command_exec_all() {
        [ -z "$*" ] && abort "Usage: $0 exec_all <command>"
        exec_ips "$(command_list_ips)" "$*"
}

# ssh to all debian-based droplets (ubuntu/debian) and execute a command
function command_exec_deb() {
        [ -z "$*" ] \
                && abort "Usage: $0 exec_all <command>"

        ips=$(list | \
                jq -r '.droplets[]
                | select(
                        .image.distribution=="Debian"
                        or
                        .image.distribution=="Ubuntu"
                )
                | .networks.v4[]
                | select(.type=="public")
                | .ip_address')

        exec_ips "$ips" "$*"
}


# ssh to all rpm-based droplets (centos/fedora) and execute a command
function command_exec_rpm() {
        [ -z "$*" ] \
                && abort "Usage: $0 exec_all <command>"

        ips=$(list | \
                jq -r '.droplets[]
                | select(
                        .image.distribution=="CentOS"
                        or
                        .image.distribution=="Fedora"
                )
                | .networks.v4[]
                | select(.type=="public")
                | .ip_address')

        exec_ips "$ips" "$*"
}

function exec_ips() {
        { [ -z "${1:-}" ] || [ -z "${2:-}" ]; } \
                && abort "Usage: exec_all <ips> <command>"

        ips=$1
        shift
        script="hostname -s; { $*; }"
        echo "Dispatching..."
        for ip in $ips; do
                # shellcheck disable=SC2029
                echo "$(echo
                        echo -n ">>>> $ip: "
                        ssh -o "StrictHostKeyChecking no" "root@${ip}" "${script}" 2>/dev/stdout || true
                )" &
        done
        wait
}

# list all droplets without formatting
function list() {
        request GET "/droplets?tag_name=$TAG"
}

function list_deb_ips() {
        list | \
                jq -r '.droplets[]
                | select(
                        .image.distribution=="Debian"
                        or
                        .image.distribution=="Ubuntu"
                )
                | .networks.v4[]
                | select(.type=="public")
                | .ip_address'
}

# create a droplet with the provided image
function create_image() {
        image=$1
        if [ -z "$image" ]; then
                abort "Usage: create_image <image>"
        else
                echo "Creating image $image..."
        fi

        user_data=${USER_DATA_RPM}
        [[ "$image" =~ debian|ubuntu ]] && user_data=${USER_DATA_DEB}

        body=$(mktemp)
        cat <<EOF > "$body"
        {
                "name": "$image",
                "region": "nyc3",
                "size": "s-1vcpu-1gb",
                "image": "$image",
                "ssh_keys": [
                        "${JONES_SSH_FINGERPRINT}",
                        "${THOR_SSH_FINGERPRINT}",
                        "${EVAN_SSH_FINGERPRINT}",
                        "${SNYDER_SSH_FINGERPRINT}"
                ],
                "backups": false,
                "ipv6": false,
                "user_data": "${user_data}",
                "tags": [ "${TAG}" ]
        }
EOF

        request POST "/droplets" "@${body}" \
                | jq -r '.droplets[] | "Created: \(.id): \(.name)"'

}


# Make an HTTP request to the API. The DATA param is optional
#
# Usage: request [METHOD] [PATH] [DATA]
#
# Examples:
#   request "GET" "/droplets"
#   request "POST" "/droplets" "@some-file.json"
#   request "POST" "/droplets" '{"some": "data"}'
#   request "DELETE" "/droplets/1234567"
function request() {
        METHOD=${1:-}
        URL=${2:-}
        DATA=${3:-}

        [ -z "$METHOD" ] && abort "Usage: request [METHOD] [PATH] [DATA]"

        if [[ ! "$URL" =~ ^/ ]] || [[ "$URL" =~ /v2 ]]; then
                abort "URL param should be a relative path not including v2 (e.g. /droplets). Got '$URL'"
        fi


        curl -SsL \
                -X "$METHOD" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer ${AUTH_TOKEN}" \
                -d "$DATA" \
                "https://api.digitalocean.com/v2$URL"
}

# ask the user for input
function ask() {
        question=${1:-}
        [ -z "$question" ] && abort "Usage: ask <question>"
        read -p "$question " -n 1 -r
        echo -n "$REPLY"
}

# ask the user for a yes or no answer. Returns 0 for yes or 1 for no.
function confirm() {
        question="$1 (y/n)"
        yn=$(ask "$question")
        echo
        [[ $yn =~ ^[Yy]$ ]] && return 0
        return 1
}

# launch a uri with the system's default application (browser)
function launch() {
        uri=${1:-}
        [ -z "$uri" ] && abort "Usage: launch <uri>"

        if [[ "$OS" =~ linux ]]; then
                xdg-open "$uri"
        else
                open "$uri"
        fi
}

function abort() {
        read -r line func file <<< "$(caller 0)"
        echo "ERROR in $file.$func:$line: $1" > /dev/stderr # we can use better logging here
        exit 1
}

# never put anything below this line. This is to prevent any partial execution
# if curl ever interrupts the download prematurely. In that case, this script
# will not execute since this is the last line in the script.
err_report() { echo "Error on line $1"; }
trap 'err_report $LINENO' ERR
main "$@"
