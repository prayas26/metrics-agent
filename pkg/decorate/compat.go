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

package decorate

import (
	"strings"

	dto "github.com/prometheus/client_model/go"
)

var conversions = map[string]string{
	"node_cpu_seconds_total":            "sonar_cpu",
	"node_disk_read_bytes_total":        "sonar_disk_sectors_read",
	"node_disk_written_bytes_total":     "sonar_disk_sectors_written",
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

// Compat decorates metrics to be backwards compatible with do-agent
type Compat struct{}

// Name is the name of this decorator
func (Compat) Name() string {
	return "compat"
}

// Decorate decorates the provided metrics for compatibility
func (Compat) Decorate(mfs []*dto.MetricFamily) {
	for _, mf := range mfs {
		n := strings.ToLower(mf.GetName())
		if newName, ok := conversions[n]; ok {
			mf.Name = &newName
		}
	}
}
