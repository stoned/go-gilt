CMD := go-gilt
GO_IMAGE ?= golang:1.17
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
define CRUN
	$(CONTAINER_ENGINE) run --rm -it \
		$(if $(findstring docker,$(CONTAINER_ENGINE)),--user $$(id -u)) \
		-v $(CURDIR):/usr/src/go-gilt:z \
		-w /usr/src/go-gilt \
		--env HOME=/tmp \
		$(IMAGE)
endef

test: fmtcheck lint vet bats
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

fmtcheck:
	@echo "+ $@"
	@bash -c "diff -u <(echo -n) <(gofmt -d .)"

lint:
	@echo "+ $@"
	@golint -set_exit_status ./...

vet:
	@echo "+ $@"
	@$(CRUN) go vet ./...

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
