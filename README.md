# Node Collector

DigitalOcean Node Collector

[![Build
Status](https://travis-ci.org/digitalocean/node_collector.svg?branch=master)](https://travis-ci.org/digitalocean/node_collector)
[![GoDoc](https://godoc.org/github.com/digitalocean/node_collector?status.svg)](https://godoc.org/github.com/digitalocean/node_collector)

Node Collector is the [do-agent](https://github.com/digitalocean/do-agent)
successor. It's purpose is to collect metrics from droplets. It does this via
[node_exporter](https://github.com/prometheus/node_exporter).

## Metrics Collected

By default, Node Collector will report all metrics enabled by default in
node_exporter (see
[here](https://github.com/prometheus/node_exporter/blob/master/README.md#enabled-by-default)).

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
dep ensure -v -add <import path> ```
```

## Installation

**TODO**
