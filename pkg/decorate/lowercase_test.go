package decorate

import (
	"strings"
	"testing"

	dto "github.com/prometheus/client_model/go"
	"github.com/stretchr/testify/assert"
)

func TestLowercaseNamesChangesLabels(t *testing.T) {
	d := LowercaseNames{}
	items := []*dto.MetricFamily{
		&dto.MetricFamily{
			Name: sptr("JKLKJSFDJKLjkasdfjklasdf"),
		},
		&dto.MetricFamily{
			Name: sptr("BLUE"),
		},
	}

	d.Decorate(items)

	for _, mf := range items {
		assert.Equal(t, strings.ToLower(mf.GetName()), mf.GetName())
	}
}

func sptr(s string) *string {
	return &s
}
