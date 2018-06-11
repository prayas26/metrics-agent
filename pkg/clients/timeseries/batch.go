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

package timeseries

import (
	"bytes"
	"encoding/binary"
	"hash/fnv"

	"github.com/digitalocean/node_collector/pkg/clients/timeseries/metrics"

	"github.com/gogo/protobuf/proto"
)

// Definition holds the description of a metric.
type Definition struct {
	// Name is the metric name
	Name string

	// CommonLabels is a set of static key-value labels
	CommonLabels map[string]string

	// MeasuredLabelKeys is a list of label keys whose values will be specified
	// at run-time
	MeasuredLabelKeys []string
}

// DefinitionOpt is an option initializer for metric registration.
type DefinitionOpt func(*Definition)

// WithCommonLabels includes common labels
func WithCommonLabels(labels map[string]string) DefinitionOpt {
	return func(o *Definition) {
		for k, v := range labels {
			o.CommonLabels[k] = v
		}
	}
}

// WithMeasuredLabels includes labels
func WithMeasuredLabels(labelKeys ...string) DefinitionOpt {
	return func(o *Definition) {
		o.MeasuredLabelKeys = append(o.MeasuredLabelKeys, labelKeys...)
	}
}

// NewDefinition returns a new definition
func NewDefinition(name string, opts ...DefinitionOpt) *Definition {
	def := &Definition{
		Name:              name,
		CommonLabels:      map[string]string{},
		MeasuredLabelKeys: []string{},
	}
	for _, opt := range opts {
		opt(def)
	}
	return def
}

// Datapoint is a single data point of a specified metric
type Datapoint struct {
	MetricDef *Definition
	Value     float64
	Labels    []string
}

func (dp *Datapoint) hash() uint64 {
	hasher := fnv.New64a()
	hasher.Reset()

	hasher.Write([]byte(dp.MetricDef.Name))
	for k, v := range dp.MetricDef.CommonLabels {
		hasher.Write([]byte(k))
		hasher.Write([]byte(v))
	}
	for _, k := range dp.MetricDef.MeasuredLabelKeys {
		hasher.Write([]byte(k))
	}
	for _, k := range dp.Labels {
		hasher.Write([]byte(k))
	}

	return hasher.Sum64()
}

// IsSameMetric returns true if both datapoints have the same name and labels
func (dp *Datapoint) IsSameMetric(rhs *Datapoint) bool {
	if dp.MetricDef.Name != rhs.MetricDef.Name {
		return false
	}
	if !EqualStringStringMaps(dp.MetricDef.CommonLabels, rhs.MetricDef.CommonLabels) {
		return false
	}
	if !EqualStringSlices(dp.MetricDef.MeasuredLabelKeys, rhs.MetricDef.MeasuredLabelKeys) {
		return false
	}
	if !EqualStringSlices(dp.Labels, rhs.Labels) {
		return false
	}
	return true
}

// Batch represents a batch of metrics to send to wharf
type Batch struct {
	datapointsByFamily map[string][]*Datapoint
	seen               map[uint64]bool
}

// NewBatch returns a new batch
func NewBatch() *Batch {
	return &Batch{
		datapointsByFamily: map[string][]*Datapoint{},
		seen:               map[uint64]bool{},
	}
}

// AddMetric adds a metric to the batch
func (b *Batch) AddMetric(def *Definition, value float64, labels ...string) {
	if len(labels) != len(def.MeasuredLabelKeys) {
		panic("supplied number of labels does not match number of MeasuredLabelKeys")
	}
	pt := &Datapoint{
		MetricDef: def,
		Value:     value,
		Labels:    labels,
	}

	hash := pt.hash()
	_, maybeSeen := b.seen[hash]

	pts, ok := b.datapointsByFamily[def.Name]
	if !ok {
		pts = []*Datapoint{}
	}
	if maybeSeen {
		for i, x := range pts {
			if x.IsSameMetric(pt) {
				// replace existing point
				pts[i] = pt
			}
		}
	} else {
		pts = append(pts, pt)
	}
	b.datapointsByFamily[def.Name] = pts
	b.seen[hash] = true
}

// IsEmpty returns true if the batch is empty
func (b *Batch) IsEmpty() bool {
	return len(b.datapointsByFamily) == 0
}

// appendDelimited appends a length-delimited protobuf message to the writer.
// Returns the number of bytes written, and any error.
func appendDelimited(out *bytes.Buffer, m proto.Message) (int, error) {
	buf, err := proto.Marshal(m)
	if err != nil {
		return 0, err
	}

	var delim [binary.MaxVarintLen32]byte
	len := binary.PutUvarint(delim[:], uint64(len(buf)))
	n, err := out.Write(delim[:len])
	if err != nil {
		return n, err
	}

	dn, err := out.Write(buf)
	return n + dn, err
}

// MetricsFamillies returns the metrics in the batch
func (b *Batch) MetricsFamillies() []*metrics.MetricFamily {
	families := []*metrics.MetricFamily{}
	for famillyName, datapoints := range b.datapointsByFamily {
		theMetrics := []*metrics.Metric{}
		for _, pt := range datapoints {

			labelPairs := []*metrics.LabelPair{}
			for k, v := range pt.MetricDef.CommonLabels {
				labelPairs = append(labelPairs, &metrics.LabelPair{Name: k, Value: v})
			}
			for i, k := range pt.MetricDef.MeasuredLabelKeys {
				v := pt.Labels[i]
				labelPairs = append(labelPairs, &metrics.LabelPair{Name: k, Value: v})
			}

			theMetrics = append(theMetrics,
				&metrics.Metric{
					Gauge: &metrics.Gauge{Value: pt.Value},
					Label: labelPairs,
				})
		}

		families = append(families, &metrics.MetricFamily{
			Name:   famillyName,
			Type:   metrics.MetricType_GAUGE, // assume everything is a gauge, as dometheus doesnt use the metric type
			Metric: theMetrics,
		})

	}
	return families
}

// Bytes returns the serialized batch
func (b *Batch) Bytes() ([]byte, error) {
	return b.serialize(false)
}

func (b *Batch) serialize(asText bool) ([]byte, error) {
	metricFamillies := b.MetricsFamillies()
	var buf bytes.Buffer
	for _, m := range metricFamillies {
		var err error
		if asText {
			err = proto.MarshalText(&buf, m)
		} else {
			_, err = appendDelimited(&buf, m)
		}
		if err != nil {
			return nil, err
		}
	}

	return buf.Bytes(), nil
}

// String returns a string for debugging purposes
func (b *Batch) String() string {
	buf, _ := b.serialize(true)
	return string(buf)
}
