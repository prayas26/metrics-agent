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
	digitalocean/fpm:latest

now          = $(shell date -u +"%F %T %Z")
git_revision = $(shell git rev-parse HEAD)
git_branch   = $(shell git rev-parse --abbrev-ref HEAD)
git_tag      = $(shell git describe --tags --abbrev=0 2>/dev/null || echo '0.0.0')

ldflags = '\
	-X "main.version=$(git_tag)" \
	-X "main.revision=$(git_revision)" \
	-X "main.branch=$(git_branch)" \
	-X "main.buildDate=$(now)" \
'

###########
## paths ##
###########

out         := target
package_dir := $(out)/pkg
cache       := $(out)/.cache
project     := $(notdir $(CURDIR))# project name
importpath  := github.com/digitalocean/$(project)# import path used in gocode
gofiles     := $(call find,go)

# the name of the binary built with local resources
local_binary        := $(out)/$(project)_$(GOOS)_$(GOARCH)
cover_profile       := $(out)/.coverprofile
GOX                 := $(shell which gox || echo $(GOPATH)/bin/gox)
supported_platforms := linux/amd64 linux/386

# output packages
deb_package := $(local_binary)_v$(git_tag).deb
rpm_package := $(local_binary)_v$(git_tag).rpm
tar_package := $(local_binary)_v$(git_tag).tar.gz

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
	@[ ! -f "$(GOX)" ] || go get github.com/mitchellh/gox

lint: $(cache)/lint
$(cache)/lint: $(gofiles)
	$(mkdir)
	gometalinter --config=gometalinter.json ./...
	$(touch)

test: $(cover_profile)
$(cover_profile): $(gofiles)
	$(mkdir)
	go test -coverprofile=$@ ./...

clean:
	rm -rf $(out)
.PHONY: clean

ci: clean lint test
.PHONY: ci

deb: $(deb_package)
$(deb_package): $(out)/$(project)_$(GOOS)_$(GOARCH)
	$(mkdir)
	$(fpm) -t deb -s dir \
		-a $(GOARCH) \
		-p $@ \
		--no-depends \
		-n $(project) \
		-m "DigitalOcean" \
		-v $(git_tag) \
		--description "DigitalOcean stats collector" \
		--license apache-2.0 \
		--vendor DigitalOcean \
		--url https://github.com/digitalocean/node_collector \
		--log info \
		--conflicts do-agent \
		--replaces do-agent \
		$^=/usr/local/bin/node_collector \
		packaging/lib/systemd/system/node_collector.service=/etc/systemd/system/multi-user.target.wants/node_collector.service
	chown -R $(USER):$(USER) target
	# print information about the compiled deb package
	@docker run --rm -it -v ${PWD}:/tmp -w /tmp ubuntu:trusty /bin/bash -c 'dpkg --info $@ && dpkg -c $@'


rpm: $(rpm_package)
$(rpm_package): $(deb_package)
	$(mkdir)
	$(fpm) -t rpm -s deb \
		-p $@ \
		$^
	chown -R $(USER):$(USER) target
	# print information about the compiled rpm package
	@docker run --rm -it -v ${PWD}:/tmp -w /tmp centos:7 rpm -qilp $@

tar: $(tar_package)
$(tar_package): $(deb_package)
	$(mkdir)
	$(fpm) -t tar -s deb \
		-p $@ \
		$^
	chown -R $(USER):$(USER) target
	# print all files within the archive
	@docker run --rm -it -v ${PWD}:/tmp -w /tmp ubuntu:trusty tar -ztvf $@
