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

import dto "github.com/prometheus/client_model/go"

// Decorator decorates a list of metric families
type Decorator interface {
	Decorate([]*dto.MetricFamily)
	Name() string
}

// Chain of decorators to be applied to the metric family
type Chain []Decorator

// Decorate the metric family
func (c Chain) Decorate(mfs []*dto.MetricFamily) {
	for _, d := range c {
		d.Decorate(mfs)
	}
}

// Name is the name of the decorator
func (c Chain) Name() string {
	return "Chain"
}
