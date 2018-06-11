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

// LowercaseNames decorates metrics to be have all lowercase label names
type LowercaseNames struct{}

// Decorate decorates the provided metrics for compatibility
func (LowercaseNames) Decorate(mfs []*dto.MetricFamily) {
	// names come back with varying cases like some_TCP_connection
	// and we want consistency so we lowercase them
	for _, fam := range mfs {
		lower := strings.ToLower(fam.GetName())
		fam.Name = &lower
	}
}

// Name is the name of this decorator
func (LowercaseNames) Name() string {
	return "LowercaseNames"
}
