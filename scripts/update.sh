#!/bin/bash
# vim: noexpandtab

main() {
	if command -v apt-get 2>/dev/null; then
		apt-get update -qq
		apt-get install -qq --only-upgrade node-collector
	elif command -v yum 2>/dev/null; then
		yum -q -y update node-collector
	fi
}


main
