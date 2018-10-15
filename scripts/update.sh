#!/usr/bin/env bash
# vim: noexpandtab

main() {
	if command -v apt-get 2&>/dev/null; then
		apt-get update -qq
		apt-get install -qq -y --only-upgrade node-collector
	elif command -v yum 2&>/dev/null; then
		yum -q -y update node-collector
	fi
}

main
