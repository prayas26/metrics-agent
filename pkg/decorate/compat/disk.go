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

const diskSectorSize = float64(512)

// Disk converts node_exporter disk metrics from bytes to sectors
type Disk struct{}

// Name is the name of this decorator
func (Disk) Name() string {
	return "disk"
}

// Decorate converts bytes to sectors
func (Disk) Decorate(mfs []*dto.MetricFamily) {
	for _, mf := range mfs {
		n := strings.ToLower(mf.GetName())
		switch n {
		case "node_disk_read_bytes_total":
			mf.Name = sptr("sonar_disk_sectors_read")
			for _, met := range mf.GetMetric() {
				met.Counter.Value = bytesToSector(met.Counter.Value)
			}
		case "node_disk_written_bytes_total":
			mf.Name = sptr("sonar_disk_sectors_written")
			for _, met := range mf.GetMetric() {
				met.Counter.Value = bytesToSector(met.Counter.Value)
			}
		}
	}
}

func bytesToSector(val *float64) *float64 {
	v := *val
	v = v / diskSectorSize
	return &v
}
