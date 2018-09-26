// Copyright 2018 DigitalOcean
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
// implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"context"
	"fmt"
	"log"
	"net/url"
	"os"
	"time"

	"github.com/digitalocean/node_collector/pkg/clients"
	"github.com/digitalocean/node_collector/pkg/clients/timeseries"
	"github.com/digitalocean/node_collector/pkg/collector"
	"github.com/digitalocean/node_collector/pkg/decorate"
	"github.com/digitalocean/node_collector/pkg/decorate/compat"
	"github.com/digitalocean/node_collector/pkg/writer"
	"github.com/pkg/errors"
	"github.com/prometheus/client_golang/prometheus"
	"gopkg.in/alecthomas/kingpin.v2"
)

var (
	config struct {
		targets     map[string]string
		metadataURL *url.URL
		authURL     *url.URL
		stdoutOnly  bool
	}

	// unsupportedCollectors is a list of collectors currently unsupported
	// by DigitalOcean. These will be elided by the server so enabling them
	// will be pointless.
	unsupportedCollectors = []string{"arp", "bcache", "bonding",
		"buddyinfo", "conntrack", "drbd", "edac", "entropy", "filefd",
		"hwmon", "infiniband", "interrupts", "ipvs", "ksmd", "logind",
		"mdadm", "meminfo_numa", "mountstats", "netdev", "netstat",
		"nfs", "nfsd", "ntp", "qdisc", "runit", "sockstat", "supervisord",
		"systemd", "tcpstat", "textfile", "wifi", "xfs", "zfs", "timex",
	}

	// additionalParams is a list of extra command line flags to append
	// this is mostly needed for appending node_exporter flags when necessary.
	additionalParams = []string{}
)

const (
	appName            = "node_collector"
	defaultMetadataURL = "http://169.254.169.254"
	defaultAuthURL     = "https://sonar.digitalocean.com"
)

func init() {
	kingpin.Flag("auth-host", "Endpoint to use for obtaining droplet app key").
		Default(defaultAuthURL).
		URLVar(&config.authURL)

	kingpin.Flag("metadata-host", "Endpoint to use for obtaining droplet metadata").
		Default(defaultMetadataURL).
		URLVar(&config.metadataURL)

	kingpin.Flag("stdout-only", "write all metrics to stdout only").
		BoolVar(&config.stdoutOnly)
}

func checkConfig() error {
	var err error
	for name, uri := range config.targets {
		if _, err = url.Parse(uri); err != nil {
			return errors.Wrapf(err, "url for target %q is not valid", name)
		}
	}
	return nil
}

func initWriter(ctx context.Context) (metricWriter, throttler) {
	if config.stdoutOnly {
		return writer.NewFile(os.Stdout), &constThrottler{wait: 10 * time.Second}
	}

	tsc, err := newTimeseriesClient(ctx)
	if err != nil {
		log.Fatalf("ERROR: failed to connect to sonar: %+v", err)
	}
	return writer.NewSonar(tsc), tsc
}

func initDecorator() decorate.Chain {
	return decorate.Chain{
		compat.Names{},
		compat.Disk{},
		compat.CPU{},
		decorate.LowercaseNames{},
	}
}

func newTimeseriesClient(ctx context.Context) (*timeseries.HTTPClient, error) {
	hc := clients.NewHTTP(time.Minute)
	md := clients.NewMetadata(hc, config.metadataURL.String())
	token, err := md.AuthToken(ctx)
	if err != nil {
		return nil, err
	}

	key, err := clients.NewAuthenticator(hc, config.authURL.String()).
		AppKey(ctx, token)
	if err != nil {
		return nil, err
	}

	meta, err := md.Meta(ctx)
	if err != nil {
		return nil, err
	}

	url := fmt.Sprintf("https://%s.sonar.digitalocean.com/v1/metrics/droplet_id/%d", meta.Region, meta.DropletID)
	return timeseries.New(hc, url, key), nil
}

// initCollectors initializes the prometheus collectors. By default this
// includes node_exporter and buildInfo for each remote target
func initCollectors() []prometheus.Collector {
	// buildInfo provides build information for tracking metrics internally
	cols := []prometheus.Collector{buildInfo}

	// create the default node collector to collect metrics about
	// this device
	node, err := collector.NewNodeCollector()
	if err != nil {
		log.Fatalf("ERROR: failed to create node collector: %+v", err)
	}
	log.Printf("INFO: %d node_exporter collectors were registered", len(node.Collectors()))

	for name := range node.Collectors() {
		log.Printf("INFO: node_exporter collector registered %q", name)
	}
	cols = append(cols, node)

	return cols
}
