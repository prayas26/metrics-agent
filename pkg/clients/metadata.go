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

package clients

import (
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"

	"github.com/pkg/errors"
)

// DropletMeta is metadata about a droplet. This is a minified version of what
// actually returns from the service. Fields can be added when necessary
type DropletMeta struct {
	DropletID int      `json:"droplet_id"`
	Hostname  string   `json:"hostname"`
	AuthKey   string   `json:"auth_key"`
	Region    string   `json:"region"`
	Tags      []string `json:"tags"`
}

// Metadata is an authentication client that authenticates with the Metadata
type Metadata struct {
	client *http.Client
	host   string
}

// NewMetadata creates a new metadata client
func NewMetadata(client *http.Client, host string) *Metadata {
	return &Metadata{
		client: client,
		host:   strings.TrimRight(host, "/"),
	}
}

// AuthToken returns a valid token to use for obtaining an appKey
func (s *Metadata) AuthToken(ctx context.Context) (string, error) {
	key, err := s.key(ctx, "auth-token")
	return strings.Trim(strings.TrimSpace(key), `"`), err
}

// Meta retrieves all droplet metadata
func (s *Metadata) Meta(ctx context.Context) (*DropletMeta, error) {
	resp, err := s.do(ctx, fmt.Sprintf("%s/metadata/v1.json", s.host))
	if err != nil {
		return nil, errors.Wrap(err, "failed to retrieve metadata")
	}
	defer resp.Body.Close()

	m := new(DropletMeta)
	err = json.NewDecoder(resp.Body).Decode(m)
	return m, errors.Wrap(err, "failed to decode meta response body")
}

func (s *Metadata) metaURL(key string) string {
	return fmt.Sprintf("%s/metadata/v1/%s", s.host, key)
}

func (s *Metadata) key(ctx context.Context, key string) (string, error) {
	resp, err := s.do(ctx, s.metaURL(key))
	if err != nil {
		return "", err
	}

	defer resp.Body.Close()
	b, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", errors.Wrap(err, "failed to parse metadata response body")
	}

	return string(b), nil
}

func (s *Metadata) do(ctx context.Context, urlPath string) (*http.Response, error) {
	req, err := http.NewRequest("GET", urlPath, nil)
	if err != nil {
		return nil, errors.Wrap(err, "failed to create HTTP request")
	}

	resp, err := s.client.Do(req.WithContext(ctx))
	return resp, errors.WithStack(err)
}
