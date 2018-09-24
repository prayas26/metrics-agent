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
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"

	"github.com/pkg/errors"
)

const authHeader = "Authorization"
const invalid = `{"valid":false}`

// ErrInvalidToken is an error indicating the token provided to AppKey was
// invalid. This is returned when the attempt to retrieve an AppKey returns
// {"valid": false}
var ErrInvalidToken = errors.New("invalid token supplied to Authenticator")

// Authenticator gets an AppKey
type Authenticator struct {
	client HTTPClient
	host   string
}

// NewAuthenticator creates a new authenticator using the provided host
func NewAuthenticator(client HTTPClient, host string) *Authenticator {
	return &Authenticator{
		client: client,
		host:   strings.TrimRight(host, "/"),
	}
}

// AppKey gets an AppKey using the provided AuthToken
func (a *Authenticator) AppKey(ctx context.Context, token string) (string, error) {
	url := fmt.Sprintf("%s/v1/appkey/droplet-auth-token", a.host)
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", errors.Wrap(err, "failed to create HTTP request")
	}
	req.Header.Add(authHeader, fmt.Sprintf("DOMETADATA %s", token))

	resp, err := a.client.Do(req.WithContext(ctx))
	if err != nil {
		return "", errors.Wrap(err, "HTTP request failed")
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return "", errors.Wrap(err, "failed to read HTTP response body")
	}
	key := string(body)

	if strings.Contains(key, invalid) {
		return "", ErrInvalidToken
	}
	return strings.Trim(strings.TrimSpace(key), `"`), err
}
