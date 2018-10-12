#!/bin/bash
set -ueo pipefail

UBUNTU_VERSIONS="trusty utopic vivid wily xenial yakkety zesty artful bionic"
DEBIAN_VERSIONS="wheezy jessie stretch buster"
RHEL_VERSIONS="6 7"
FEDORA_VERSIONS="27 28"

main() {
	[ -z "${PACKAGECLOUD_TOKEN:-}" ] && \
		echo "PACKAGECLOUD_TOKEN is unset and required" && \
		exit 1
	[[ ! "${VERSION:-}" =~ v[0-9]+\.[0-9]+\.[0-9]+ ]] && \
		echo "Specify the version to promote with VERSION=v0.0.0 $0" > /dev/stderr && \
		exit 1

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

check_version() {
	version=${1:-}
	[ -z "${version}" ] && abort "Usage: ${FUNCNAME[0]} <version>"
	version=${version/v}

	url=https://packagecloud.io/digitalocean-insights/node-collector-beta/packages/ubuntu/zesty/node-collector_${version}_amd64.deb
	echo "Checking for version at $url..."
	curl --fail-early --fail -SsLI "${url}" | grep 'HTTP/1'
}

promote() {
	distro=${1:-}
	distro_release=${2:-}
	target=${3:-}

	{ [ -z "$distro" ] || [ -z "$distro_release" ] || [ -z "$target" ]; } \
		&& abort "Usage: promote [distro] [distro_release] [target]"

	package_cloud promote \
		"digitalocean-insights/node-collector-beta/$distro/$distro_release" \
		"$target" \
		"digitalocean-insights/node-collector"
}

package_cloud() {
	docker run -e "PACKAGECLOUD_TOKEN=${PACKAGECLOUD_TOKEN}" \
		-v "$PWD:/tmp" \
		-w /tmp \
		--rm \
		rwgrim/package_cloud \
		"$*"
}

function abort() {
	read -r line func file <<< "$(caller 0)"
	echo "ERROR in $file.$func:$line: $1" > /dev/stderr
	exit 1
}


main
