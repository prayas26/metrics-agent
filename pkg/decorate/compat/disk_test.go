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
	"testing"

	dto "github.com/prometheus/client_model/go"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var counterMetricType = dto.MetricType(0)

func TestDiskChangesNames(t *testing.T) {
	m := map[string]string{
		"node_disk_read_bytes_total":    "sonar_disk_sectors_read",
		"node_disk_written_bytes_total": "sonar_disk_sectors_written",
	}

	dec := Disk{}
	for old, new := range m {
		t.Run(old, func(t *testing.T) {
			mfs := []*dto.MetricFamily{
				{Name: &old},
			}
			dec.Decorate(mfs)

			assert.Equal(t, new, mfs[0].GetName())
		})
	}
}

func TestDiskConvertsBytesToSectors(t *testing.T) {
	names := []string{
		"node_disk_read_bytes_total",
		"node_disk_written_bytes_total",
	}

	for _, name := range names {
		// make sure to reset num for every test since it's a pointer
		num := 63219712.0
		exp := num / diskSectorSize

		dec := Disk{}
		metric := dto.Metric{
			Counter: &dto.Counter{Value: &num},
		}

		t.Run(name, func(t *testing.T) {
			mfs := []*dto.MetricFamily{
				&dto.MetricFamily{
					Type:   &counterMetricType,
					Name:   &name,
					Metric: []*dto.Metric{&metric},
				},
			}
			dec.Decorate(mfs)
			require.EqualValues(t, exp, metric.Counter.GetValue())
		})
	}
}

func TestDiskHasName(t *testing.T) {
	assert.NotEmpty(t, Disk{}.Name())
}
