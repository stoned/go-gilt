GO_IMAGE ?= golang:1.17
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

test: fmtcheck lint vet bats
	@echo "+ $@"
	@go test -tags=integration -parallel 5 -covermode=count ./...

bats:
	@echo "+ $@"
	@./test/integration/vendor/bats/bin/bats test/integration

cover:
	@echo "+ $@"
	@go test -tags=integration -coverprofile=coverage.out -covermode=count ./...
	@go tool cover -html=coverage.out -o=coverage.html

fmt:
	@echo "+ $@"
	@gofmt -s -l -w .

fmtcheck:
	@echo "+ $@"
	@bash -c "diff -u <(echo -n) <(gofmt -d .)"

lint:
	@echo "+ $@"
	@golint -set_exit_status ./...

vet:
	@echo "+ $@"
	@go vet ./...

clean:
	@echo "+ $@"
	@rm -rf $(BUILDDIR)

define BUILD
	@echo "+ $@"
	@docker run --rm -it \
		--user $$(id -u) \
		-v $(CURDIR):/usr/src/go-gilt:z \
		-w /usr/src/go-gilt \
		$(GO_IMAGE) \
		env HOME=/tmp GOOS=$(GOOS) GOARCH=$(GOARCH) GO111MODULE=on make in-container-build
endef

build: clean build-linux-amd64 build-darwin-amd64

build-linux-amd64: GOOS=linux GOARCH=amd64
build-linux-amd64:
	$(BUILD)

build-darwin-amd64: GOOS=darwin GOARCH=amd64
build-darwin-amd64:
	$(BUILD)

in-container-build:
	go build -v \
	-ldflags="$(LDFLAGS)" \
	-o "$(BUILDDIR)/go-gilt_$$(go env GOOS)_$$(go env GOARCH)"
