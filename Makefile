GOOS        ?= linux
GOARCH      ?= amd64

############
## macros ##
############

find  = $(shell find . -name \*.$1 -type f)
mkdir = @mkdir -p $(dir $@)
cp    = @cp $< $@
print = @echo "\n:::::::::::::::: [$(shell date -u)] $@ ::::::::::::::::"
touch = @touch $@
fpm   = docker run --rm -it \
	-v ${PWD}:/tmp \
	-w /tmp \
	-u $(shell id -u) \
	digitalocean/fpm:latest

now          = $(shell date -u +"%F %T %Z")
git_revision = $(shell git rev-parse HEAD)
git_branch   = $(shell git rev-parse --abbrev-ref HEAD)
git_tag      = $(shell git describe --tags --abbrev=0 2>/dev/null || echo 'v0.0.0')
version      = $(subst v,,$(git_tag))
ldflags      = '\
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
supported_platforms := linux/amd64 linux/386

# output packages
deb_package := $(subst $(out),$(package_dir),$(local_binary)_$(git_tag).deb)
rpm_package := $(subst $(out),$(package_dir),$(local_binary)_$(git_tag).rpm)
tar_package := $(subst $(out),$(package_dir),$(local_binary)_$(git_tag).tar.gz)

#############
## targets ##
#############

build: $(local_binary)
$(local_binary): $(gofiles)
	$(print)
	@GOOS=$(GOOS) GOARCH=$(GOARCH) \
	     go build \
	     -ldflags $(ldflags) \
	     -o "$@" \
	     ./cmd/$(project)

package: release
release:
	$(print)
	@GOOS=linux GOARCH=amd64 $(MAKE) build deb rpm tar
	@GOOS=linux GOARCH=386 $(MAKE) build deb rpm tar

lint: $(cache)/lint
$(cache)/lint: $(gofiles)
	$(print)
	$(mkdir)
	@gometalinter --config=gometalinter.json ./...
	$(touch)

test: $(cover_profile)
$(cover_profile): $(gofiles)
	$(print)
	$(mkdir)
	@go test -coverprofile=$@ ./...

clean:
	$(print)
	@rm -rf $(out)
.PHONY: clean

ci: clean lint test
.PHONY: ci

deb: $(deb_package)
$(deb_package): $(local_binary)
	$(print)
	$(mkdir)
	@$(fpm) --output-type deb \
		--input-type dir \
		--architecture $(GOARCH) \
		--package $@ \
		--no-depends \
		--name $(project) \
		--maintainer "DigitalOcean" \
		--version $(version) \
		--description "DigitalOcean stats collector" \
		--license apache-2.0 \
		--vendor DigitalOcean \
		--url https://github.com/digitalocean/node_collector \
		--log info \
		--conflicts do-agent \
		--replaces do-agent \
		--after-install packaging/scripts/after_install.sh \
		--before-upgrade packaging/scripts/before_upgrade.sh \
		--after-upgrade packaging/scripts/after_upgrade.sh \
		--after-remove packaging/scripts/after_remove.sh \
		packaging/etc/init/node-collector.conf=/opt/digitalocean/scripts/ \
		packaging/lib/systemd/system/node-collector.service=/opt/digitalocean/scripts/ \
		$^=/usr/local/bin/node_collector
	chown -R $(USER):$(USER) target
# print information about the compiled deb package
	@docker run --rm -it -v ${PWD}:/tmp -w /tmp ubuntu:xenial /bin/bash -c 'dpkg --info $@ && dpkg -c $@'


rpm: $(rpm_package)
$(rpm_package): $(deb_package)
	$(print)
	$(mkdir)
	@$(fpm) -t rpm -s deb \
		-p $@ \
		$^
	chown -R $(USER):$(USER) target
# print information about the compiled rpm package
	@docker run --rm -it -v ${PWD}:/tmp -w /tmp centos:7 rpm -qilp $@

tar: $(tar_package)
$(tar_package): $(deb_package)
	$(print)
	$(mkdir)
	@$(fpm) -t tar -s deb \
		-p $@ \
		$^
	chown -R $(USER):$(USER) target
# print all files within the archive
	@docker run --rm -it -v ${PWD}:/tmp -w /tmp ubuntu:xenial tar -ztvf $@
