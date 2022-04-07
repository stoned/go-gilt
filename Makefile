CMD := go-gilt
GO_IMAGE ?= golang:1.17
GOLANGCI_LINT_IMAGE ?= golangci/golangci-lint:v1.45.2
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

IMAGE= $(GO_IMAGE)
DOCKER_ONLY_RUN_ARGS= $(if $(findstring docker,$(CONTAINER_ENGINE)),--user $$(id -u))
define CRUN
	$(CONTAINER_ENGINE) run --rm -i \
		$(DOCKER_ONLY_RUN_ARGS) \
		-v $(CURDIR):/usr/src/go-gilt:z \
		-w /usr/src/go-gilt \
		--env HOME=/tmp \
		$(IMAGE)
endef

test: lint go-test bats

go-test:
	@echo "+ $@"
	@$(CRUN) go test -tags=integration -parallel 5 -covermode=count ./...

bats:
	@echo "+ $@"
	@./test/integration/vendor/bats/bin/bats test/integration

cover:
	@echo "+ $@"
	@$(CRUN) go test -tags=integration -coverprofile=coverage.out -covermode=count ./...
	@$(CRUN) go tool cover -html=coverage.out -o=coverage.html

fmt:
	@echo "+ $@"
	@$(CRUN) gofmt -s -l -w .

lint: IMAGE=$(GOLANGCI_LINT_IMAGE)
lint:
	@echo "+ $@"
	@$(CRUN) golangci-lint run -v

clean:
	@echo "+ $@"
	@rm -rf $(BUILDDIR)

define BUILD
	@$(CRUN) go build -ldflags="$(LDFLAGS)" -o "$(BUILDDIR)/$(CMD)_$(GOOS)_$(GOARCH)"
endef

build: clean build-linux-amd64 build-darwin-amd64

build-linux-amd64: GOOS=linux
build-linux-amd64: GOARCH=amd64
build-linux-amd64:
	@echo "+ $@"
	$(BUILD)

build-darwin-amd64: GOOS=darwin
build-darwin-amd64: GOARCH=amd64
build-darwin-amd64:
	@echo "+ $@"
	$(BUILD)
