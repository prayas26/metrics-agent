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
cover_profile := $(out)/.coverprofile
GOX                 :=$(shell which gox || echo $(GOPATH)/bin/gox)
supported_platforms := linux/amd64 linux/386

#############
## targets ##
#############

$(GOX):
	[ -z "$(GOX)" ] || go get github.com/mitchellh/gox

build: $(local_binary)
$(local_binary): $(gofiles)
	GOOS=$(GOOS) GOARCH=$(GOARCH) \
	     go build \
		-ldflags $(ldflags) \
	     	-o "$@" \
		./cmd/node_collector

release: $(out)/$(project)
$(out)/$(project): $(GOX) $(gofiles)
	@$(GOX) -osarch="$(supported_platforms)" \
		-output "$@_{{.OS}}_{{.Arch}}" \
		-ldflags $(ldflags) \
		./cmd/node_collector

lint: $(cache)/lint
$(cache)/lint: $(gofiles)
	$(mkdir)
	gometalinter --config=gometalinter.json ./...
	$(touch)

test: $(cover_profile)
$(cover_profile): $(gofiles)
	$(mkdir)
	go test -coverprofile=$@ ./...
	$(touch)

clean:
	rm -rf $(out)
.PHONY: clean

ci: clean lint test
.PHONY: ci
