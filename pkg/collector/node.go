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

package collector

import (
	"github.com/pkg/errors"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/node_exporter/collector"
)

// NewNodeCollector creates a new prometheus NodeCollector
func NewNodeCollector() (*NodeCollector, error) {
	c, err := collector.NewNodeCollector()
	if err != nil {
		return nil, errors.Wrap(err, "failed to create NodeCollector")
	}

	return &NodeCollector{
		collectFunc:  c.Collect,
		describeFunc: c.Describe,
		collectorsFunc: func() map[string]collector.Collector {
			return c.Collectors
		},
	}, nil
}

// NodeCollector is a collector that collects data using
// prometheus/node_exporter. Since prometheus returns an internal type we have
// to wrap it with our own type
type NodeCollector struct {
	collectFunc    func(ch chan<- prometheus.Metric)
	describeFunc   func(ch chan<- *prometheus.Desc)
	collectorsFunc func() map[string]collector.Collector
}

// Collectors returns the list of collectors registered
func (n *NodeCollector) Collectors() map[string]collector.Collector {
	return n.collectorsFunc()
}

// Name returns the name of this collector
func (n *NodeCollector) Name() string {
	return "node_collector"
}

// Collect collects metrics using prometheus/node_exporter
func (n *NodeCollector) Collect(ch chan<- prometheus.Metric) {
	n.collectFunc(ch)
}

// Describe describes the metrics collected using prometheus/node_exporter
func (n *NodeCollector) Describe(ch chan<- *prometheus.Desc) {
	n.describeFunc(ch)
}
