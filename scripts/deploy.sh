#!/usr/bin/env bash
set -ueo pipefail
# set -x

UBUNTU_VERSIONS="trusty utopic vivid wily xenial yakkety zesty artful bionic"
DEBIAN_VERSIONS="wheezy jessie stretch buster"
RHEL_VERSIONS="6 7"
FEDORA_VERSIONS="27 28"

VERSION="${VERSION:-$(cat target/VERSION 2>/dev/null)}"

# display usage for this script
function usage() {
	cat <<-EOF
	NAME:
	
	  $(basename "$0")
	
	SYNOPSIS:

	  $0 <cmd>

	DESCRIPTION:

	    The purpose of this script is to publish artifacts to Github and
	    PackageCloud. Deployments push artifacts in Prerelease or BETA
	    mode.  After they are published and tested in the BETA/Prerelease
	    phase they can then be promoted.

	ENVIRONMENT:
		
	    VERSION (required)
	         The version to publish or promote

	    GITHUB_AUTH_USER
	         Github user to use for publishing to Github
	         Required for github deploy

	    GITHUB_AUTH_TOKEN
	         Github access token to use for publishing to Github
	         Required for github deploy

	    PACKAGECLOUD_TOKEN
	         PackageCloud token used for deployments and promotion
	         Required for promote or packagecloud deploy

	    SPACES_ACCESS_KEY_ID
	         Spaces key ID to use for Spaces deployment
	         Required for Spaces deploy

	    SPACES_SECRET_ACCESS_KEY
	         Spaces secret access key ID to use for Spaces deployment
	         Required for Spaces deploy

	    SLACK_WEBHOOK_URL
	         Webhook URL to send notifications
	         Optional: enables Slack notifications

	COMMANDS:
	
	    spaces
	         deploy the install script to insights Spaces

	    github
	         push target/ assets to github

	    packagecloud
	         push target/pkg/ packages to packagecloud

	    all
	         push to spaces, github, and packagecloud

	    promote
	         promote VERSION from packagecloud beta to upstream and remove
	         the prerelease flag from the Github release

	EOF
}

function main() {
	cmd=${1:-}

	case "$cmd" in
		all)
			check_version
			deploy_spaces
			deploy_github
			deploy_packagecloud
			wait
			;;
		github)
			check_version
			deploy_github
			;;
		spaces)
			check_version
			deploy_spaces
			;;
		packagecloud)
			check_version
			deploy_packagecloud
			;;
		promote)
			check_version
			promote_packagecloud
			promote_github
			;;
		help)
			usage
			exit 0
			;;
		*)
			usage
			exit 1
			;;
	esac
}

# verify the VERSION env var
function check_version() {
	[[ "${VERSION}" =~ v[0-9]+\.[0-9]+\.[0-9]+ ]] || \
		abort "VERSION env var should be semver format (e.g. v0.0.1)"
}

# deploy the install script to digitalocean spaces insights.nyc3
function deploy_spaces() {
	aws s3 \
		--endpoint-url https://nyc3.digitaloceanspaces.com \
		cp ./target/scripts/metrics-agent-install.sh \
		s3://insights/metrics-agent-install.sh
}


# deploy the compiled binaries and packages to github releases
function deploy_github() {
	if ! create_github_release ; then
		echo "Aborting github deploy"
		exit 1
	fi
	upload_url=$(github_asset_upload_url)

	for file in $(target_files); do
		name=$(basename "$file")

		echo "Uploading $name to github"
		github_curl \
			-X "POST" \
			-H 'Content-Type: application/octet-stream' \
			-d "@${file}" \
			"$upload_url?name=$name" \
			| jq -r '. | "Success: \(.name)"' &
	done
	wait
}

# deploy the compiled packages to packagecloud
function deploy_packagecloud() {
	deb_files=$(target_files | grep '\.deb$')
	rpm_files=$(target_files | grep '\.rpm$')
	for uv in $UBUNTU_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/metrics-agent-beta/ubuntu/$uv" \
			"$deb_files" &
	done

	for dv in $DEBIAN_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/metrics-agent-beta/debian/$dv" \
			"$deb_files" &
	done

	for rv in $RHEL_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/metrics-agent-beta/el/$rv" \
			"$rpm_files" &
	done

	for fv in $FEDORA_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/metrics-agent-beta/fedora/$fv" \
			"$rpm_files" &
	done

	wait
}

# remove the prerelease flag from the github release for VERSION
function promote_github() {
	if ! url=$(github_release_url); then
		abort "Github release for $VERSION does not exist"
	fi

	echo "Removing github prerelease tag for $VERSION"
	github_curl \
		-o /dev/null \
		-X PATCH \
		-H 'Content-Type: application/json' \
		-d '{ "prerelease": false }' \
		"$url"
}

# promote VERSION packagecloud packages from beta to upstream
function promote_packagecloud() {
	[ -z "${PACKAGECLOUD_TOKEN}" ] && abort "unbound variable PACKAGECLOUD_TOKEN"
	check_packagecloud_version \
		|| abort "Version ${VERSION} was not found on Packagecloud.io"

	echo "Promoting PackageCloud ${VERSION}"
	deb64="metrics-agent_${VERSION/v}_amd64.deb"
	deb32="metrics-agent_${VERSION/v}_i386.deb"
	rpm64="metrics-agent-${VERSION/v}-1.x86_64.rpm"
	rpm32="metrics-agent-${VERSION/v}-1.i386.rpm"

	for uv in $UBUNTU_VERSIONS; do
		promote "ubuntu" "$uv" "$deb64" &
		promote "ubuntu" "$uv" "$deb32" &
	done

	for dv in $DEBIAN_VERSIONS; do
		promote "debian" "$dv" "$deb64" &
		promote "debian" "$dv" "$deb32" &
	done

	for rv in $RHEL_VERSIONS; do
		promote "el" "$rv" "$rpm64" &
		promote "el" "$rv" "$rpm32" &
	done

	for fv in $FEDORA_VERSIONS; do
		promote "fedora" "$fv" "$rpm64" &
		promote "fedora" "$fv" "$rpm32" &
	done

	wait
}

# interact with package_cloud cli via docker
function package_cloud() {
	docker run -e "PACKAGECLOUD_TOKEN=${PACKAGECLOUD_TOKEN}" \
		-v "$PWD:/tmp" \
		-w /tmp \
		--rm \
		rwgrim/package_cloud \
		"$*"
}

# verify the packagecloud version exists in the beta repository before
# attempting to promote
function check_packagecloud_version() {
	v=${VERSION/v}

	url=https://packagecloud.io/digitalocean-insights/metrics-agent-beta/packages/ubuntu/zesty/metrics-agent_${v}_amd64.deb
	echo "Checking for version $v"
	curl --fail-early \
		--fail \
		-SsLI \
		"${url}" \
		| grep 'HTTP/1'
}

# promote a distro/release package from beta to upstream
function promote() {
	distro=${1:-}; distro_release=${2:-}; target=${3:-}

	if [ -z "$distro" ] || [ -z "$distro_release" ] || [ -z "$target" ]; then
		abort "Usage: ${FUNCNAME[0]} <distro> <distro_release> <target>"
	fi

	package_cloud promote \
		"digitalocean-insights/metrics-agent-beta/$distro/$distro_release" \
		"$target" \
		"digitalocean-insights/metrics-agent"
}

# interact with the awscli via docker
function aws() {
	docker run \
		--rm -t "$(tty &>/dev/null && echo '-i')" \
		-e "AWS_ACCESS_KEY_ID=${SPACES_ACCESS_KEY_ID}" \
		-e "AWS_SECRET_ACCESS_KEY=${SPACES_SECRET_ACCESS_KEY}" \
		-e "AWS_DEFAULT_REGION=nyc3" \
		-v "$(pwd):/project" \
		-w /project \
		mesosphere/aws-cli \
		"$@"
}

# get the asset upload URL for VERSION
function github_asset_upload_url() {
	github_curl \
		"https://api.github.com/repos/digitalocean/metrics-agent/releases/tags/$VERSION" \
		| jq -r '. | "https://uploads.github.com/repos/digitalocean/metrics-agent/releases/\(.id)/assets"'
}

# get the base release url for VERSION
function github_release_url() {
	github_curl \
		"https://api.github.com/repos/digitalocean/metrics-agent/releases/tags/$VERSION" \
		| jq -r '. | "https://api.github.com/repos/digitalocean/metrics-agent/releases/\(.id)"'
}


# create a github release for VERSION
function create_github_release() {
	if github_asset_upload_url; then
		echo "Github release exists $VERSION"
		return 0
	fi

	echo "Creating Github release $VERSION"
	data="{ \"tag_name\": \"$VERSION\", \"prerelease\": true }"
	echo "$data"

	github_curl \
		-o /dev/null \
		-X POST \
		-H 'Content-Type: application/json' \
		-d "$data" \
		https://api.github.com/repos/digitalocean/metrics-agent/releases
}

# list the artifacts within the target/ directory
function target_files() {
	v=${VERSION/v}
	if ! packages=$(find target/pkg -type f -iname "*$v*"); then
		abort "No packages for $VERSION were found in target/.  Did you forget to run make?"
	fi

	ls target/metrics-agent_linux_*
	echo "$packages"
}

# call CURL with github authentication
function github_curl() {
	# if user and token are empty then bash will exit because of unbound vars
	curl -SsL \
		--fail \
		--fail-early \
		-u "${GITHUB_AUTH_USER}:${GITHUB_AUTH_TOKEN}" \
		"$@"
}

# ask the user for input
function ask() {
	question=${1:-}
	[ -z "$question" ] && abort "Usage: ${FUNCNAME[0]} <question>"
	read -p "$question " -r
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

# abort with an error message
function abort() {
	read -r line func file <<< "$(caller 0)"
	echo "ERROR in $file:$func:$line: $1" > /dev/stderr
	exit 1
}

# send a slack notification
# Usage: notify_slack <success> <msg> [link]
#
# Examples:
#    notify_slack 0 "Deployed to Github failed!"
#    notify_slack "true" "Success!" "https://github.com/"
#
function notify_slack() {
	if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
		echo "env var SLACK_WEBHOOK_URL is unset. Not sending notification" > /dev/stderr
		return 0
	fi

	success=${1:-}
	msg=${3:-}
	link=${2:-}

	color="green"
	[[ "$success" =~ ^(false|0|no)$ ]] && color="red"

	payload=$(cat <<-EOF
	{
	  "attachments": [
	    {
	      "fallback": "${msg}",
	      "color": "${color}",
	      "title": "${msg}",
	      "title_link": "${link}",
	      "fields": [
		{
		  "title": "User",
		  "value": "${USER}",
		  "short": true
		},
		{
		  "title": "Source",
		  "value": "$(hostname -s)",
		  "short": true
		}
	      ]
	    }
	  ]
	}
	EOF
	)

	curl -sS -X POST \
		--fail-early \
		--fail \
		--data "$payload" \
		"${SLACK_WEBHOOK_URL}" > /dev/null

	# always pass to prevent pipefailures
	return 0
}


main "$@"
