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
	"testing"

	dto "github.com/prometheus/client_model/go"
	"github.com/stretchr/testify/assert"
)

func TestCompatConvertsLabels(t *testing.T) {
	for old, new := range conversions {
		t.Run(old, func(t *testing.T) {
			mfs := []*dto.MetricFamily{
				{Name: &old},
			}
			Compat{}.Decorate(mfs)

			assert.Equal(t, new, mfs[0].GetName())
		})
	}
}

func TestCompatIsCaseInsensitive(t *testing.T) {
	for old, new := range conversions {
		t.Run(old, func(t *testing.T) {
			mfs := []*dto.MetricFamily{
				{Name: sptr(strings.ToUpper(old))},
			}
			Compat{}.Decorate(mfs)

			assert.Equal(t, new, mfs[0].GetName())
		})
	}
}
