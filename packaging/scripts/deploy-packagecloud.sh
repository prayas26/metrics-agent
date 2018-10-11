#!/bin/bash
set -ue

# This script fails for 'PACKAGECLOUD_TOKEN: unbound variable' when the env var
# is unset. This var is required for execution of package_cloud. This snippet
# is here just in case.
[ -z "$PACKAGECLOUD_TOKEN" ] && \
	echo "PACKAGECLOUD_TOKEN is unset and required" && \
	exit 1

UBUNTU_VERSIONS="trusty utopic vivid wily xenial yakkety zesty artful bionic"
DEBIAN_VERSIONS="wheezy jessie stretch buster"
RHEL_VERSIONS="6 7"
FEDORA_VERSIONS="27 28"

main() {
	for uv in $UBUNTU_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/node-collector/ubuntu/$uv" \
			./target/pkg/*.deb &
	done

	for dv in $DEBIAN_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/node-collector/debian/$dv" \
			./target/pkg/*.deb &
	done

	for rv in $RHEL_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/node-collector/el/$rv" \
			./target/pkg/*.rpm &
	done

	for fv in $FEDORA_VERSIONS; do
		package_cloud push \
			"digitalocean-insights/node-collector/fedora/$fv" \
			./target/pkg/*.rpm &
	done

	wait
}


package_cloud () {
	docker run -e "PACKAGECLOUD_TOKEN=${PACKAGECLOUD_TOKEN}" \
		-v "$PWD:/tmp" \
		-w /tmp \
		--rm \
		rwgrim/package_cloud \
		"$*"
}


main
