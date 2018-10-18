# DigitalOcean Metrics Agent

**WIP Notice**

DigitalOcean Metrics Agent is a work in progress

[![Build
Status](https://travis-ci.org/digitalocean/metrics-agent.svg?branch=master)](https://travis-ci.org/digitalocean/metrics-agent)
[![Go Report Card](https://goreportcard.com/badge/github.com/digitalocean/metrics-agent)](https://goreportcard.com/report/github.com/digitalocean/metrics-agent)
[![Coverage Status](https://coveralls.io/repos/github/digitalocean/metrics-agent/badge.svg?branch=feat%2Fadd-coveralls-report)](https://coveralls.io/github/digitalocean/metrics-agent?branch=feat%2Fadd-coveralls-report)

## Overview
The DigialOcean Metrics agent is a drop in replacement and improvement for [do-agent](https://github.com/digitalocean/do-agent). The Metrics Agent enables droplet metrics to be gathered and sent to DigitalOcean to provide resource usage graphs and alerting. Rather than use `procfs` to obtain resource usage data, we use [node_exporter](https://github.com/prometheus/node_exporter).

Metrics Agent currently supports:
- Ubuntu 14.04+
- Debian 8+
- Fedora 27+
- CentOS 6+

## Development

### Requirements

- [go](https://golang.org/dl/)
- [golang/dep](https://github.com/golang/dep#installation)
- [GNU Make](https://www.gnu.org/software/make/)
- [Go Meta Linter](https://github.com/alecthomas/gometalinter#installing)

```
git clone git@github.com:digitalocean/metrics-agent.git \
        $GOPATH/src/github.com/digitalocean/metrics-agent
cd !$

# build the project
make

# add dependencies
dep ensure -v -add <import path>
```

## Installation
The Metrics Agent can be installed by running

```
curl -sL https://insights.nyc3.cdn.digitaloceanspaces.com/metrics-agent-install.sh | sudo bash
```

If you already have `do-agent` installed you should see it removed during the install process.

or you may manually remove it first by running
 
 `apt remove do-agent` / `yum remove do-agent` and then running `metrics-agent-install.sh`

### Uninstall

Metrics Agent can be uninstalled with your distribution's package manager

`apt remove metrics-agent` for Debian based distros

`yum remove metrics-agent` for RHEL based distros

## Report an Issue
Feel free to [open an issue](https://github.com/digitalocean/metrics-agent/issues/new) if one does not [already exist](https://github.com/digitalocean/metrics-agent/issues)
