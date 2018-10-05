#!/bin/bash
set -uxe

UBUNTU_VERSIONS="trusty utopic vivid wily xenial yakkety zesty artful bionic"
DEBIAN_VERSIONS="wheezy jessie stretch buster"
RHEL_VERSIONS="6 7"
FEDORA_VERSIONS="27 28"

main() {
        if [ -z "${PACKAGECLOUD_TOKEN+x}" ]; then
                echo "PACKAGECLOUD_TOKEN is unset. Exiting..." > /dev/stderr
                exit 1
        fi

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
