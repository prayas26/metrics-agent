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
	"context"
	"log"
	"os"
	"time"

	"github.com/digitalocean/node_collector/pkg/decorate"
	"github.com/prometheus/client_golang/prometheus"
	dto "github.com/prometheus/client_model/go"
	kingpin "gopkg.in/alecthomas/kingpin.v2"
)

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	os.Args = append(os.Args, additionalParams...)

	// parse all command line flags
	kingpin.HelpFlag.Short('h')
	kingpin.Parse()

	if err := checkConfig(); err != nil {
		log.Fatal("ERROR: configuration failure: ", err)
	}

	cols := initCollectors()
	reg := prometheus.NewRegistry()
	reg.MustRegister(cols...)

	w, th := initWriter(ctx)
	d := initDecorator()
	run(ctx, w, th, d, reg)

	<-ctx.Done()
}

type metricWriter interface {
	Write(mets []*dto.MetricFamily) error
	Name() string
}

type throttler interface {
	WaitDuration() time.Duration
	Name() string
}

type gatherer interface {
	Gather() ([]*dto.MetricFamily, error)
}

func run(ctx context.Context, w metricWriter, th throttler, dec decorate.Decorator, g gatherer) {
	exec := func() {
		start := time.Now()
		mfs, err := g.Gather()
		if err != nil {
			log.Printf("ERROR: failed to gather metrics: %v\n", err)
			return
		}
		log.Println("INFO: stats collected in", time.Since(start))

		start = time.Now()
		dec.Decorate(mfs)
		log.Println("INFO: stats decorated in", time.Since(start))

		err = w.Write(mfs)
		if err != nil {
			log.Printf("ERROR: failed to send metrics: %v", err)
			return
		}
		log.Println("INFO: stats written in", time.Since(start))
	}

	exec()

	for {
		select {
		case <-time.After(th.WaitDuration()):
			exec()
		case <-ctx.Done():
			return
		}
	}
}
