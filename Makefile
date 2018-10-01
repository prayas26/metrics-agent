GOOS ?= linux
GOARCH ?= amd64

############
## macros ##
############

find  = $(shell find . -name \*.$1 -type f)
mkdir = @mkdir -p $(dir $@)
cp    = @cp $< $@
print = @echo $@...
touch = @touch $@
fpm   = docker run --rm -it \
	-v ${PWD}:/tmp \
	-w /tmp \
	-u $(shell id -u) \
	digitalocean/fpm:latest \
	-n $(project) \
	-m "DigitalOcean" \
	-v $(git_tag) \
	--description "DigitalOcean stats collector" \
	--license apache-2.0 \
	--vendor DigitalOcean \
	--url https://github.com/digitalocean/node_collector \
	--log info \
	--conflicts do-agent \
	--replaces do-agent

git_revision = $(shell git rev-parse HEAD)
git_tag = $(shell git describe --tags 2>/dev/null || echo '0.0.0')
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

out        := target
cache      := $(out)/.cache
# project name
project    := $(notdir $(CURDIR))
# import path used in gocode
importpath := github.com/digitalocean/$(project)
gofiles    := $(call find,go)

# the name of the binary built with local resources
local_binary        := $(out)/$(project)_$(GOOS)_$(GOARCH)
cover_profile       := $(out)/.coverprofile
GOX                 := $(shell which gox || echo $(GOPATH)/bin/gox)
supported_platforms := linux/amd64 linux/386

# output packages
fpm_image           := digitalocean/$(project)
debian_package      := $(local_binary)-$(git_tag)-$(GOARCH).deb
rpm_package         := $(local_binary)-$(git_tag)-$(GOARCH).rpm
tar_package         := $(local_binary)-$(git_tag)-$(GOARCH).tar.gz

#############
## targets ##
#############

build: $(local_binary)
$(local_binary): $(gofiles)
	GOOS=$(GOOS) GOARCH=$(GOARCH) \
	     go build \
	     -ldflags $(ldflags) \
	     -o "$@" \
	     ./cmd/$(project)

release:
	$(GOX) -osarch="$(supported_platforms)" \
		-output "$(out)/$(project)_{{.OS}}_{{.Arch}}" \
		-ldflags $(ldflags) \
		./cmd/$(project)

$(GOX):
	[ -z "$(GOX)" ] || go get github.com/mitchellh/gox

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

debian: $(debian_package)
$(debian_package): $(out)/$(project)_$(GOOS)_$(GOARCH)
	$(fpm) -t deb -s dir \
		-a $(GOARCH) \
		-p $@ \
		--no-depends \
		$^=/usr/local/bin/node_collector \
		packaging/lib/systemd/system/node_collector.service=/etc/systemd/system/multi-user.target.wants
	chown -R $(USER):$(USER) target
	@docker run --rm -it -v ${PWD}:/tmp -w /tmp ubuntu:trusty /bin/bash -c 'dpkg --info $@ && dpkg -c $@'


rpm: $(rpm_package)
$(rpm_package): $(debian_package)
	$(fpm) -t rpm -s deb \
		-p $@ \
		$^
	chown -R $(USER):$(USER) target
	@docker run --rm -it -v ${PWD}:/tmp -w /tmp centos:7 rpm -qilp $@
