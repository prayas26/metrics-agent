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
	"net/url"
	"os"
	"strings"
	"time"

	"github.com/digitalocean/node_collector/internal/log"
	"github.com/digitalocean/node_collector/pkg/clients/tsclient"
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
		targets       map[string]string
		metadataURL   *url.URL
		authURL       *url.URL
		sonarEndpoint string
		stdoutOnly    bool
		debug         bool
		syslog        bool
	}

	// additionalParams is a list of extra command line flags to append
	// this is mostly needed for appending node_exporter flags when necessary.
	additionalParams = []string{}

	// disabledCollectors is a hash used by disableCollectors to prevent
	// duplicate entries
	disabledCollectors = map[string]interface{}{}
)

const (
	appName            = "node_collector"
	defaultMetadataURL = "http://169.254.169.254/metadata"
	defaultAuthURL     = "https://sonar.digitalocean.com"
	defaultSonarURL    = ""
)

func init() {
	kingpin.Flag("auth-host", "Endpoint to use for obtaining droplet app key").
		Default(defaultAuthURL).
		URLVar(&config.authURL)

	kingpin.Flag("metadata-host", "Endpoint to use for obtaining droplet metadata").
		Default(defaultMetadataURL).
		URLVar(&config.metadataURL)

	kingpin.Flag("sonar-host", "Endpoint to use for delivering metrics").
		Default(defaultSonarURL).
		StringVar(&config.sonarEndpoint)

	kingpin.Flag("stdout-only", "write all metrics to stdout only").
		BoolVar(&config.stdoutOnly)

	kingpin.Flag("debug", "display debug information to stdout").
		BoolVar(&config.debug)

	kingpin.Flag("syslog", "enable logging to syslog").
		BoolVar(&config.syslog)
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
		log.Fatal("failed to connect to sonar: %+v", err)
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

// WrappedTSClient wraps the tsClient and adds a Name method to it
type WrappedTSClient struct {
	tsclient.Client
}

// Name returns the name of the client
func (m *WrappedTSClient) Name() string { return "tsclient" }

func newTimeseriesClient(ctx context.Context) (*WrappedTSClient, error) {
	clientOptions := []tsclient.ClientOptFn{
		tsclient.WithUserAgent(fmt.Sprintf("node-collector-%s", revision)),
		tsclient.WithRadarEndpoint(config.authURL.String()),
		tsclient.WithMetadataEndpoint(config.metadataURL.String()),
	}

	if config.sonarEndpoint != "" {
		clientOptions = append(clientOptions, tsclient.WithWharfEndpoint(config.sonarEndpoint))
	}

	if config.debug {
		logger := func(msg string) {
			fmt.Println(strings.TrimSpace(msg))
		}
		clientOptions = append(clientOptions, tsclient.WithLogger(logger))
	}

	tsClient := tsclient.New(clientOptions...)
	wrappedTSClient := &WrappedTSClient{tsClient}

	return wrappedTSClient, nil
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
		log.Fatal("failed to create node collector: %+v", err)
	}
	log.Info("%d node_exporter collectors were registered", len(node.Collectors()))

	for name := range node.Collectors() {
		log.Info("node_exporter collector registered %q", name)
	}
	cols = append(cols, node)

	return cols
}

// disableCollectors disables collectors by names by adding a list of
// --no-collector.<name> flags to additionalParams
func disableCollectors(names ...string) {
	f := []string{}
	for _, name := range names {
		if _, ok := disabledCollectors[name]; ok {
			// already disabled
			continue
		}

		disabledCollectors[name] = nil
		f = append(f, disableCollectorFlag(name))
	}

	additionalParams = append(additionalParams, f...)
}

// disableCollectorFlag creates the correct cli flag for the given collector name
func disableCollectorFlag(name string) string {
	return fmt.Sprintf("--no-collector.%s", name)
}
