# Node Collector

**WIP Notice**

DigitalOcean Node Collector is a work in progress

[![Build
Status](https://travis-ci.org/digitalocean/node_collector.svg?branch=master)](https://travis-ci.org/digitalocean/node_collector)
[![Go Report Card](https://goreportcard.com/badge/github.com/digitalocean/node_collector)](https://goreportcard.com/report/github.com/digitalocean/node_collector)
[![Coverage Status](https://coveralls.io/repos/github/digitalocean/node_collector/badge.svg?branch=feat%2Fadd-coveralls-report)](https://coveralls.io/github/digitalocean/node_collector?branch=feat%2Fadd-coveralls-report)

## Development

### Requirements

- [go](https://golang.org/dl/)
- [golang/dep](https://github.com/golang/dep#installation)
- [GNU Make](https://www.gnu.org/software/make/)
- [Go Meta Linter](https://github.com/alecthomas/gometalinter#installing)

```
git clone git@github.com:digitalocean/node_collector.git \
        $GOPATH/src/github.com/digitalocean/node_collector
cd !$

# build the project
make

# add dependencies
dep ensure -v -add <import path>
```

## Installation

**TODO**
