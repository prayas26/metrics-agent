GOOS   ?= linux
GOARCH ?= amd64

ifeq ($(GOARCH),386)
PKG_ARCH = i386
else
PKG_ARCH = amd64
endif

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
pkg_project := $(subst _,-,$(project))# package cannot have underscores in the name
importpath  := github.com/digitalocean/$(project)# import path used in gocode
gofiles     := $(call find,go)

# the name of the binary built with local resources
binary             := $(out)/$(project)_$(GOOS)_$(GOARCH)
cover_profile      := $(out)/.coverprofile

# output packages
# deb files should end with _version_arch.deb
# rpm files should end with -version-release.arch.rpm
deb_package := $(package_dir)/$(pkg_project)_$(version)_$(PKG_ARCH).deb
rpm_package := $(package_dir)/$(pkg_project)-$(version)-1.$(PKG_ARCH).rpm
tar_package := $(subst .deb,.tar.gz,$(deb_package))

#############
## targets ##
#############

build: $(binary)
$(binary):
	$(print)
	$(mkdir)
	GOOS=$(GOOS) GOARCH=$(GOARCH) \
	     go build \
	     -ldflags $(ldflags) \
	     -o "$@" \
	     ./cmd/$(project)

package: release
release:
	$(print)
	@GOOS=linux GOARCH=386 $(MAKE) build deb rpm tar
	@GOOS=linux GOARCH=amd64 $(MAKE) build deb rpm tar

lint: $(cache)/lint
$(cache)/lint: $(gofiles)
	$(print)
	$(mkdir)
	@gometalinter --config=gometalinter.json ./...
	$(touch)

shellcheck: $(cache)/shellcheck
$(cache)/shellcheck:
	$(print)
	$(mkdir)
	@shellcheck packaging/scripts/*.sh
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

ci: clean lint shellcheck test
.PHONY: ci

deb: $(deb_package)
$(deb_package): $(binary)
	$(print)
	$(mkdir)
	@$(fpm) --output-type deb \
		--input-type dir \
		--force \
		--architecture $(PKG_ARCH) \
		--package $@ \
		--no-depends \
		--name $(pkg_project) \
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
		--after-remove packaging/scripts/after_remove.sh \
		--deb-group nobody \
		--deb-user nobody \
		packaging/etc/init/node-collector.conf=/opt/digitalocean/node_collector/scripts/ \
		packaging/lib/systemd/system/node-collector.service=/opt/digitalocean/node_collector/scripts/ \
		$<=/usr/local/bin/node_collector
	chown -R $(USER):$(USER) target
# print information about the compiled deb package
	@docker run --rm -it -v ${PWD}:/tmp -w /tmp ubuntu:xenial /bin/bash -c 'dpkg --info $@ && dpkg -c $@'


rpm: $(rpm_package)
$(rpm_package): $(deb_package)
	$(print)
	$(mkdir)
	@$(fpm) \
		--output-type rpm \
		--input-type deb \
		--rpm-group nobody \
		--rpm-user nobody \
		--force \
		-p $@ \
		$^
	chown -R $(USER):$(USER) target
# print information about the compiled rpm package
	@docker run --rm -it -v ${PWD}:/tmp -w /tmp centos:7 rpm -qilp $@

tar: $(tar_package)
$(tar_package): $(deb_package)
	$(print)
	$(mkdir)
	@$(fpm) \
		--output-type tar \
		--input-type deb \
		--force \
		-p $@ \
		$^
	chown -R $(USER):$(USER) target
# print all files within the archive
	@docker run --rm -it -v ${PWD}:/tmp -w /tmp ubuntu:xenial tar -ztvf $@
