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
	"fmt"
	"log"
	"strconv"
	"strings"

	dto "github.com/prometheus/client_model/go"
)

// CPU converts node_exporter cpu labels from 0-indexed to 1-indexed with prefix
type CPU struct{}

// Name is the name of this decorator
func (c CPU) Name() string {
	return fmt.Sprintf("%T", c)
}

// Decorate executes the decorator against the give metrics
func (CPU) Decorate(mfs []*dto.MetricFamily) {
	for _, mf := range mfs {
		if !strings.EqualFold(mf.GetName(), "node_cpu_seconds_total") {
			continue
		}

		mf.Name = sptr("sonar_cpu")
		for _, met := range mf.GetMetric() {
			for _, l := range met.GetLabel() {
				if !strings.EqualFold(l.GetName(), "cpu") {
					continue
				}
				num, err := strconv.Atoi(l.GetValue())
				if err != nil {
					log.Printf("ERROR: failed to parse cpu number: %+v\n", l)
					continue
				}

				l.Value = sptr(fmt.Sprintf("cpu%d", num+1))
			}
		}
	}
}
