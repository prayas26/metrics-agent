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
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/pkg/errors"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestAppKeyErrorsWithInvalidHost(t *testing.T) {
	token := fmt.Sprintf("%d", time.Now().UnixNano())

	var called bool
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		fmt.Fprintln(w, invalid)
	}))
	defer srv.Close()

	subject := NewAuthenticator(srv.Client(), " #$%^&*( ")
	_, err := subject.AppKey(context.TODO(), token)
	require.Error(t, err)
	assert.False(t, called, "http request was made")
}

func TestAppKeyErrorsWhenClientDoFails(t *testing.T) {
	expected := errors.New("do not pass go")
	cl := &FakeHTTPClient{
		DoFunc: func(*http.Request) (*http.Response, error) {
			return nil, expected
		},
	}

	subject := NewAuthenticator(cl, "")
	_, err := subject.AppKey(context.TODO(), "")
	require.Equal(t, expected, errors.Cause(err))
}

func TestAppKeyPassesAuthTokenHeader(t *testing.T) {
	token := fmt.Sprintf("%d", time.Now().UnixNano())

	expected := fmt.Sprintf("DOMETADATA %s", token)
	var actual string
	var called bool

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		actual = r.Header.Get(authHeader)
	}))
	defer srv.Close()

	subject := NewAuthenticator(srv.Client(), srv.URL)
	subject.AppKey(context.TODO(), token)
	assert.True(t, called, "http request was not made")
	require.Equal(t, expected, actual)
}

func TestAppKeyIdentifiesInvalidRequest(t *testing.T) {
	token := fmt.Sprintf("%d", time.Now().UnixNano())

	var called bool
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		fmt.Fprintln(w, invalid)
	}))
	defer srv.Close()

	subject := NewAuthenticator(srv.Client(), srv.URL)
	_, err := subject.AppKey(context.TODO(), token)
	require.True(t, called, "http request was not made")
	require.Equal(t, ErrInvalidToken, err)
}

func TestAppKeyProperlyParsesKey(t *testing.T) {
	token := fmt.Sprintf("%d", time.Now().UnixNano())
	// app key returned for the droplet comes as a string in the body
	// For Example:
	//   body: '"the_key_here"\n'
	// it needs to be stripped and the quotes need to be removed
	key := `"thekey"`
	var actual string

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, key)
		// append a new line to ensure that it's stripped
		fmt.Fprintln(w, "")
	}))
	defer srv.Close()

	subject := NewAuthenticator(srv.Client(), srv.URL)
	actual, err := subject.AppKey(context.TODO(), token)
	require.NoError(t, err)
	expected := "thekey"
	require.Equal(t, expected, actual)
}
