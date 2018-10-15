# Node Collector

**WIP Notice**

DigitalOcean Node Collector is a work in progress

[![Build
Status](https://travis-ci.org/digitalocean/metrics-agent.svg?branch=master)](https://travis-ci.org/digitalocean/metrics-agent)
[![Go Report Card](https://goreportcard.com/badge/github.com/digitalocean/metrics-agent)](https://goreportcard.com/report/github.com/digitalocean/metrics-agent)
[![Coverage Status](https://coveralls.io/repos/github/digitalocean/metrics-agent/badge.svg?branch=feat%2Fadd-coveralls-report)](https://coveralls.io/github/digitalocean/metrics-agent?branch=feat%2Fadd-coveralls-report)

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

**TODO**
