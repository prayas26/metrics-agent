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

package main

import (
	"fmt"
	"os"
	"runtime"
	"text/template"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	kingpin "gopkg.in/alecthomas/kingpin.v2"
)

var (
	version   string
	revision  string
	branch    string
	buildDate string
	goVersion = runtime.Version()
)

var versionTmpl = template.Must(template.New("version").Parse(`
{{ .name }} (DigitalOcean Node Collector)  {{ .version }}
Branch:      {{.branch}}
Revision:    {{.revision}}
Build Date:  {{.buildDate}}
Go Version:  {{.goVersion}}
Website:     https://github.com/digitalocean/metrics-agent

Copyright (c) {{.year}} DigitalOcean, Inc. All rights reserved.

This work is licensed under the terms of the Apache 2.0 license.
For a copy, see <https://www.apache.org/licenses/LICENSE-2.0.html>.
`))

var buildInfo = prometheus.NewGaugeVec(
	prometheus.GaugeOpts{
		Namespace: appName,
		Name:      "build_info",
		Help: fmt.Sprintf(
			"A metric with a constant '1' value labeled by version from which %s was built.",
			appName,
		),
	},
	[]string{"version", "revision"},
).WithLabelValues(version, revision)

func init() {
	buildInfo.Set(1)
	kingpin.VersionFlag = kingpin.Flag("version", "Show the application version information").
		Short('v').
		PreAction(func(c *kingpin.ParseContext) error {
			versionTmpl.Execute(os.Stdout, map[string]string{
				"name":      appName,
				"version":   version,
				"branch":    branch,
				"revision":  revision,
				"buildDate": buildDate,
				"goVersion": goVersion,
				"year":      fmt.Sprintf("%d", time.Now().UTC().Year()),
			})
			os.Exit(0)
			return nil
		})
	kingpin.VersionFlag.Bool()

}
