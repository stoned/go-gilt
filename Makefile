CMD := go-gilt
GO_IMAGE ?= docker.io/golang:1.17.9
GOLANGCI_LINT_IMAGE ?= docker.io/golangci/golangci-lint:v1.45.2
CONTAINER_ENGINE ?= docker
GITCOMMIT ?= $(shell git rev-parse --short HEAD)
$(if $(GITCOMMIT), , $(error "git rev-parse failed"))
GITUNTRACKEDCHANGES := $(shell git status --porcelain --untracked-files=no)
ifneq ($(GITUNTRACKEDCHANGES),)
GITCOMMIT := $(GITCOMMIT)-dirty
endif
VERSION ?= $(shell git describe --tags --always)
$(if $(VERSION), , $(error "git describe failed"))
BUILDDATE := $(shell date '+%Y/%m/%d %H:%M:%S')
LDFLAGS := -s \
		-w \
		-X 'main.version=$(VERSION)' \
		-X 'main.buildHash=$(GITCOMMIT)' \
		-X 'main.buildDate=$(BUILDDATE)'
BUILDDIR := .build
SRCDIR := /src

DOCKER_ONLY_RUN_ARGS= $(if $(findstring docker,$(CONTAINER_ENGINE)),--user $$(id -u))
define CRUN
	$(CONTAINER_ENGINE) run --rm -i \
		$(DOCKER_ONLY_RUN_ARGS) \
		-v $(CURDIR):$(SRCDIR):z \
		-w $(SRCDIR) \
		--env HOME=/tmp
endef

test: lint go-test bats

go-test:
	@echo "+ $@"
	@$(CRUN) $(GO_IMAGE) go test -tags=integration -parallel 5 -covermode=count ./...

bats: bats-recent-git bats-older-git

bats-recent-git: $(BUILDDIR)/$(CMD)_linux_amd64
	@echo "+ $@"
	@$(CRUN) --env GO_GILT_CMD=$(SRCDIR)/$(BUILDDIR)/$(CMD)_linux_amd64 docker.io/bitnami/git:2.36.0 ./test/integration/vendor/bats/bin/bats test/integration

# Git 1.8.5 introduced 'git -C', we want to test go-gilt with a git version
# *without* this option
# We do not use the CRUN variable as we want to run aas root in the container
# to be able to use yum(1) and when docker is used, CRUN adds a `--user ...` option
bats-older-git: $(BUILDDIR)/$(CMD)_linux_amd64
	@echo "+ $@"
	@$(CONTAINER_ENGINE) run --rm -i \
	  -v $(CURDIR):$(SRCDIR):z -w $(SRCDIR) --env HOME=/tmp \
	  --env GO_GILT_CMD=$(SRCDIR)/$(BUILDDIR)/$(CMD)_linux_amd64 \
	  quay.io/centos/centos:7.6.1810 bash -ec 'yum install -q -y git; git --version | fgrep 1.8.3; ./test/integration/vendor/bats/bin/bats test/integration'

cover:
	@echo "+ $@"
	@$(CRUN) $(GO_IMAGE) go test -tags=integration -coverprofile=coverage.out -covermode=count ./...
	@$(CRUN) $(GO_IMAGE) go tool cover -html=coverage.out -o=coverage.html

fmt:
	@echo "+ $@"
	@$(CRUN) $(GO_IMAGE) gofmt -s -l -w .

lint:
	@echo "+ $@"
	@$(CRUN) $(GOLANGCI_LINT_IMAGE) golangci-lint run -v

clean:
	@echo "+ $@"
	@rm -rf $(BUILDDIR)

define BUILD
	@$(CRUN) --env GOOS=$(GOOS) --env GOARCH=$(GOARCH) $(GO_IMAGE) go build -ldflags="$(LDFLAGS)" -o "$(BUILDDIR)/$(CMD)_$(GOOS)_$(GOARCH)"
endef

build: clean $(BUILDDIR)/$(CMD)_linux_amd64 $(BUILDDIR)/$(CMD)_darwin_amd64 $(BUILDDIR)/$(CMD)_windows_amd64

$(BUILDDIR)/$(CMD)_linux_amd64: GOOS=linux
$(BUILDDIR)/$(CMD)_linux_amd64: GOARCH=amd64
$(BUILDDIR)/$(CMD)_linux_amd64:
	@echo "+ $@"
	$(BUILD)

$(BUILDDIR)/$(CMD)_darwin_amd64: GOOS=darwin
$(BUILDDIR)/$(CMD)_darwin_amd64: GOARCH=amd64
$(BUILDDIR)/$(CMD)_darwin_amd64:
	@echo "+ $@"
	$(BUILD)

$(BUILDDIR)/$(CMD)_windows_amd64: GOOS=windows
$(BUILDDIR)/$(CMD)_windows_amd64: GOARCH=amd64
$(BUILDDIR)/$(CMD)_windows_amd64:
	@echo "+ $@"
	$(BUILD)
