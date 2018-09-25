GOOS ?= linux
GOARCH ?= amd64

############
## macros ##
############

find = $(shell find . -name \*.$1 -type f)
mkdir = @mkdir -p $(dir $@)
cp = @cp $< $@
print = @echo $@...
touch = @touch $@

git_revision = $(shell git rev-parse HEAD)
git_tag = $(shell git describe --tags 2>/dev/null || echo 'v0.0.0')
git_branch = $(shell git rev-parse --abbrev-ref HEAD)
now = $(shell date -u +"%F %T %Z")

ldflags = '\
	-X "main.version=$(git_tag)" \
	-X "main.revision=$(git_revision)" \
	-X "main.branch=$(git_branch)" \
	-X "main.buildDate=$(now)" \
'

###########
## paths ##
###########

out := target
cache := $(out)/.cache
# project name
project := $(notdir $(CURDIR))
# import path used in gocode
importpath := github.com/digitalocean/$(project)
gofiles := $(call find,go)

# the name of the binary built with local resources
local_binary := $(out)/$(project)_$(GOOS)_$(GOARCH)
systemdconfig := packaging/lib/systemd/system/node_collector.service
systemd := $(out)/systemd/$(project).service

#############
## targets ##
#############

build: $(local_binary)
$(local_binary): $(gofiles)
	@GOOS=$(GOOS) GOARCH=$(GOARCH) \
	     go build \
		-ldflags $(ldflags) \
	     	-o "$@" \
		./cmd/node_collector

release: $(out)/$(project)
$(out)/$(project): $(gofiles)
	$(print)
	@gox -os="linux" -arch="amd64 386" \
		-ldflags $(ldflags) \
		-output "$@_{{.OS}}_{{.Arch}}" \
		./cmd/node_collector

systemd: $(systemd)
$(systemd): $(systemdconfig)
	$(print)
	$(mkdir)
	cp $(systemdconfig) $@

lint: $(cache)/lint
$(cache)/lint: $(gofiles)
	$(print)
	@gometalinter --config=gometalinter.json ./...
	$(touch)

test: $(cache)/test
$(cache)/test: $(gofiles)
	$(mkdir)
	@go test ./...
	$(touch)

ci: lint test
.PHONY: ci
