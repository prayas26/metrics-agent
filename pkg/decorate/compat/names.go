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

package compat

import (
	"strings"

	dto "github.com/prometheus/client_model/go"
)

// nameConversions is a list of metrics which differ only in name
var nameConversions = map[string]string{
	"node_cpu_seconds_total":            "sonar_cpu",
	"node_network_receive_bytes_total":  "sonar_network_receive_bytes",
	"node_network_transmit_bytes_total": "sonar_network_transmit_bytes",
	"node_memory_memtotal_bytes":        "sonar_memory_total",
	"node_memory_memfree_bytes":         "sonar_memory_free",
	"node_memory_cached_bytes":          "sonar_memory_cached",
	"node_filesystem_size_bytes":        "sonar_filesystem_size",
	"node_filesystem_free_bytes":        "sonar_filesystem_free",
	"node_load1":                        "sonar_load1",
	"node_load5":                        "sonar_load5",
	"node_load15":                       "sonar_load15",
}

// Names converts node_exporter metric names to sonar names
type Names struct{}

// Name is the name of this decorator
func (Names) Name() string {
	return "names"
}

// Decorate decorates the provided metrics for compatibility
func (Names) Decorate(mfs []*dto.MetricFamily) {
	for _, mf := range mfs {
		n := strings.ToLower(mf.GetName())
		if newName, ok := nameConversions[n]; ok {
			mf.Name = &newName
		}
	}
}

func sptr(s string) *string {
	return &s
}
