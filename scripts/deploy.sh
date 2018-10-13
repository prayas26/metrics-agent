#!/usr/bin/env bash
set -ueo pipefail

UBUNTU_VERSIONS="trusty utopic vivid wily xenial yakkety zesty artful bionic"
DEBIAN_VERSIONS="wheezy jessie stretch buster"
RHEL_VERSIONS="6 7"
FEDORA_VERSIONS="27 28"

function main() {
	cmd=${1:-}
	require_version() {
		[[ "${VERSION:-}" =~ v[0-9]+\.[0-9]+\.[0-9]+ ]] || \
			abort "VERSION env var needed. Example: VERSION=v0.0.1 $0"
	}


	case "$cmd" in
		all)
			require_version
			deploy_spaces
			deploy_github
			deploy_packagecloud
			wait
			;;
		github)
			require_version
			deploy_github
			;;
		spaces)
			require_version
			deploy_spaces
			;;
		packagecloud)
			require_version
			deploy_packagecloud
			;;
		promote)
			require_version
			deploy_promote
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

function usage() {
	cat <<-EOF

	Usage:   VERSION=<version> $0 <cmd>
	Example: VERSION=v0.0.1 $0 spaces
	
	Commands:
	
	  spaces:       deploy the install script to insights Spaces
	  github:       push the assets to github
	  packagecloud: push target/pkg packages to packagecloud
	  all:          push to spaces, github, and packagecloud
	  promote:      promote VERSION from packagecloud beta to upstream

	EOF
}

# deploy the install script to digitalocean spaces insights.nyc3
function deploy_spaces() {
	aws s3 \
		--endpoint-url https://nyc3.digitaloceanspaces.com \
		cp ./target/scripts/node-collector-install.sh \
		s3://insights/node-collector-install.sh
}


# deploy the compiled binaries and packages to github releases
function deploy_github() {
	if ! create_github_release ; then
		echo "Aborting github deploy"
		exit 1
	fi

	files=$(ls ./target/node_collector_linux_386 ./target/node_collector_linux_amd64 ./target/pkg/*)

	for f in $files; do
		name=$(basename "$f")
		echo "Uploading $name to github..."
		github "POST" "/releases/$VERSION/assets?name=$name" "@${f}" "application/x-binary"
	done
}

# deploy the compiled packages to packagecloud
function deploy_packagecloud() {
	for uv in $UBUNTU_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/node-collector-beta/ubuntu/$uv" \
			./target/pkg/*.deb &
	done

	for dv in $DEBIAN_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/node-collector-beta/debian/$dv" \
			./target/pkg/*.deb &
	done

	for rv in $RHEL_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/node-collector-beta/el/$rv" \
			./target/pkg/*.rpm &
	done

	for fv in $FEDORA_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/node-collector-beta/fedora/$fv" \
			./target/pkg/*.rpm &
	done

	wait
}

# promote the packagecloud beta VERSION to upstream
function deploy_promote() {
	check_version "${VERSION}" \
		|| abort "Version ${VERSION} was not found on Packagecloud.io"

	echo "Promoting ${VERSION}..."

	for uv in $UBUNTU_VERSIONS; do
		promote "ubuntu" "$uv" "node-collector_${VERSION}_amd64.deb" &
		promote "ubuntu" "$uv" "node-collector_${VERSION}_i386.deb" &
	done

	for dv in $DEBIAN_VERSIONS; do
		promote "debian" "$dv" "node-collector_${VERSION}_amd64.deb" &
		promote "debian" "$dv" "node-collector_${VERSION}_i386.deb" &
	done

	for rv in $RHEL_VERSIONS; do
		promote "el" "$rv" "node-collector-${VERSION}-1.x86_64.rpm" &
		promote "el" "$rv" "node-collector-${VERSION}-1.i386.rpm" &
	done

	for fv in $FEDORA_VERSIONS; do
		promote "fedora" "$fv" "node-collector-${VERSION}-1.x86_64.rpm" &
		promote "fedora" "$fv" "node-collector-${VERSION}-1.i386.rpm" &
	done

	wait
}

# interact with package_cloud cli via docker
function package_cloud() {
	[ -z "${PACKAGECLOUD_TOKEN:-}" ] && \
		abort "PACKAGECLOUD_TOKEN env var is required"

	docker run -e "PACKAGECLOUD_TOKEN=${PACKAGECLOUD_TOKEN}" \
		-v "$PWD:/tmp" \
		-w /tmp \
		--rm \
		rwgrim/package_cloud \
		"$*"
}

# verify the packagecloud version exists in the beta repository before
# attempting to promote
function check_version() {
	version=${1:-}
	[ -z "${version}" ] && abort "Usage: ${FUNCNAME[0]} <version>"
	version=${version/v}

	url=https://packagecloud.io/digitalocean-insights/node-collector-beta/packages/ubuntu/zesty/node-collector_${version}_amd64.deb
	echo "Checking for version at $url..."
	curl --fail-early --fail -SsLI "${url}" | grep 'HTTP/1'
}

# promote a distro/release package from beta to upstream
function promote() {
	distro=${1:-}
	distro_release=${2:-}
	target=${3:-}

	{ [ -z "$distro" ] || [ -z "$distro_release" ] || [ -z "$target" ]; } \
		&& abort "Usage: promote <distro> <distro_release> <target>"

	package_cloud promote \
		"digitalocean-insights/node-collector-beta/$distro/$distro_release" \
		"$target" \
		"digitalocean-insights/node-collector"
}

# interact with the awscli via docker
function aws() {
	[ -z "$AWS_ACCESS_KEY_ID" ] && abort "env var AWS_ACCESS_KEY_ID is required"
	[ -z "$AWS_SECRET_ACCESS_KEY" ] && abort "env var AWS_SECRET_ACCESS_KEY is required"

	docker run \
		--rm -t "$(tty &>/dev/null && echo \"-i\")" \
		-e "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}" \
		-e "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}" \
		-e "AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-nyc3}" \
		-v "$(pwd):/project" \
		-w /project \
		mesosphere/aws-cli \
		"$@"
}

# Make an HTTP request to the API
#
# Usage: github <METHOD> <PATH> [DATA] [CONTENT_TYPE]
#
# Examples:
#   github "GET" "/droplets"
#   github "POST" "/droplets" "@some-file.json"
#   github "POST" "/droplets" '{"some": "data"}' 'application/json'
#   github "DELETE" "/droplets/1234567"
function github() {
	[ -z "${GITHUB_AUTH_TOKEN:-}" ] && abort "GITHUB_AUTH_TOKEN env var is required"

	METHOD=${1:-}
	URL=${2:-}
	DATA=${3:-}
	CONTENT_TYPE=${4:-application/json}

	[ -z "$METHOD" ] && abort "Usage: ${FUNCNAME[0]} <METHOD> <PATH> [DATA] [CONTENT_TYPE]"

	if [[ ! "$URL" =~ ^/ ]] || [[ "$URL" =~ /v2 ]]; then
		abort "URL param should be a relative path not including v2 (e.g. /droplets). Got '$URL'"
	fi


	curl -SsL \
		--fail \
		-X "$METHOD" \
		-H "Content-Type: $CONTENT_TYPE" \
		-H "Authorization: Bearer ${GITHUB_AUTH_TOKEN}" \
		-d "$DATA" \
		"https://github.com/repos/digitalocean/node_collector$URL"
}

function create_github_release() {
	if github "GET" "/releases/$VERSION" ; then
		echo "Github release exists $VERSION"
		return 0
	fi

	tty -s || abort "Github release creation requires an interactive shell"

	confirm "The Github release does not exist. Would you like to create it?" \
		|| return 1

	commit=$(ask "For which branch/commit? (ctrl-c to cancel)")
	[ -z "$commit" ] && return 1

	prerelease="false"
	if confirm "Is this a prerelease/beta?"; then
		prerelease="true"
	fi

	echo "Creating Github release..."
	body=$(mktemp --suffix=.json)
	cat <<-EOF | tee "$body"
	{
	  "tag_name": "$VERSION",
	  "target_commitish": "$commit",
	  "name": "$VERSION",
	  "draft": false,
	  "prerelease": $prerelease
	}
	EOF
	confirm "Proceed?" || return 1

	github "POST" "/releases" "@$body" "application/json" \
		| jq .
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
	if [ -z "${SLACK_WEBHOOK_URL}" ]; then
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
