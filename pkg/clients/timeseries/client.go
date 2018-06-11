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
	"encoding/json"
	"io/ioutil"
	"math/rand"
	"net/http"
	"strconv"
	"time"
)

const (
	delimitedTelemetryContentType = "application/vnd.google.protobuf; proto=io.prometheus.client.MetricFamily; encoding=delimited"
	pushIntervalHeaderKey         = "X-Metric-Push-Interval"
	authKeyHeader                 = "X-Auth-Key"
	contentTypeHeader             = "Content-Type"
	defaultWaitInterval           = time.Second * 60
	maxWaitInterval               = time.Hour
)

// HTTPClient is used to send metrics via http
type HTTPClient struct {
	httpClient             *http.Client
	url                    string
	appKey                 string
	lastSend               time.Time
	waitInterval           time.Duration
	numConsecutiveFailures int
}

// ClientOptions are client options
type ClientOptions struct {
	WharfEndpoint string
	AppName       string
	AppKey        string
	Timeout       time.Duration
	IsTrusted     bool
}

// ClientOptFn allows for overriding options
type ClientOptFn func(*ClientOptions)

// WithWharfEndpoint overrides the default wharf endpoint -- this must be used when metadata is disabled
func WithWharfEndpoint(endpoint string) ClientOptFn {
	return func(o *ClientOptions) {
		o.WharfEndpoint = endpoint
	}
}

// WithTimeout overrides the default wharf endpoint
func WithTimeout(timeout time.Duration) ClientOptFn {
	return func(o *ClientOptions) {
		o.Timeout = timeout
	}
}

// WithTrustedAppKey overrides the metadata auth with a static trusted appkey
func WithTrustedAppKey(appName, appKey string) ClientOptFn {
	return func(o *ClientOptions) {
		o.AppKey = appKey
		o.IsTrusted = true
	}
}

// New creates a new client
func New(client *http.Client, host, appKey string) *HTTPClient {
	return &HTTPClient{
		url:          host,
		appKey:       appKey,
		httpClient:   client,
		waitInterval: defaultWaitInterval,
	}
}

// WaitDuration returns the duration before the next batch of metrics will be accepted
func (c *HTTPClient) WaitDuration() time.Duration {
	d := time.Since(c.lastSend)
	waitInterval := c.waitInterval
	if c.numConsecutiveFailures > 0 {
		waitInterval = time.Duration(c.numConsecutiveFailures)*c.waitInterval + time.Duration(rand.Intn(15))*time.Second
	}
	if waitInterval > maxWaitInterval {
		waitInterval = maxWaitInterval
	}
	d = waitInterval - d
	if d < 0 {
		return 0
	}
	return d
}

// SendMetrics sends a batch of metrics
func (c *HTTPClient) SendMetrics(batch *Batch) error {
	if c.WaitDuration() > 0 {
		return ErrSendTooFrequent
	}

	if batch.IsEmpty() {
		return nil
	}

	batchBytes, err := batch.Bytes()
	if err != nil {
		return err
	}

	// Set wait interval here in case the post fails, otherwise if it succeeds
	// the server will set it with whatever wait interval has been set
	c.lastSend = time.Now()

	req, err := http.NewRequest("POST", c.url, bytes.NewBuffer(batchBytes))
	if err != nil {
		c.numConsecutiveFailures++
		return err
	}

	req.Header.Set(contentTypeHeader, delimitedTelemetryContentType)
	req.Header.Add(authKeyHeader, c.appKey)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		c.numConsecutiveFailures++
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusAccepted {
		c.numConsecutiveFailures++
		return &UnexpectedHTTPStatusError{StatusCode: resp.StatusCode}
	}

	sendInterval, err := strconv.Atoi(resp.Header.Get(pushIntervalHeaderKey))
	if err != nil {
		c.waitInterval = defaultWaitInterval
	} else {
		c.waitInterval = time.Duration(sendInterval) * time.Second
	}
	c.numConsecutiveFailures = 0
	return nil
}

// Name is the name of this writer
func (c *HTTPClient) Name() string {
	return "HTTPClient"
}

func GetAppKey(authToken string) (string, error) {
	body, err := httpGet("https://sonar.digitalocean.com/v1/appkey/droplet-auth-token", authToken)
	if err != nil {
		return "", err
	}

	var appKey string
	err = json.Unmarshal([]byte(body), &appKey)
	if err != nil {
		return "", err
	}

	return appKey, nil
}

func httpGet(url, authToken string) (string, error) {
	client := &http.Client{}

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", err
	}
	if authToken != "" {
		req.Header.Add("Authorization", "DOMETADATA "+authToken)
	}

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	return string(body), nil
}
