PROGRAM_NAME = pgcenter

SOURCE = ${PROGRAM_NAME}.go
COMMIT=$(shell git rev-parse --short HEAD)
BRANCH=$(shell git rev-parse --abbrev-ref HEAD)
TAG=$(shell git describe --tags |cut -d- -f1)

LDFLAGS = -ldflags "-X github.com/lesovsky/pgcenter/cmd.gitTag=${TAG} \
-X github.com/lesovsky/pgcenter/cmd.gitCommit=${COMMIT} \
-X github.com/lesovsky/pgcenter/cmd.gitBranch=${BRANCH}"

.PHONY: help clean dep build install uninstall

.DEFAULT_GOAL := help

help: ## Display this help screen.
	@echo "Makefile available targets:"
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  * \033[36m%-15s\033[0m %s\n", $$1, $$2}'

clean: ## Clean build directory.
	rm -f ./bin/${PROGRAM_NAME}
	rmdir ./bin

dep: ## Download the dependencies.
	go mod download

#lint: ## Lint the source files
#	golangci-lint run --timeout 5m -E golint -e '(struct field|type|method|func) [a-zA-Z`]+ should be [a-zA-Z`]+'
#	gosec -quiet ./...

test: dep ## Run tests
	go test -race -timeout 300s -coverprofile=.test_coverage.txt ./... && \
    	go tool cover -func=.test_coverage.txt | tail -n1 | awk '{print "Total test coverage: " $$3}'
	@rm .test_coverage.txt

race: dep ## Run data race detector
	go test -race -short -timeout 300s -p 1 ./...

build: dep ## Build pgcenter executable.
	mkdir -p ./bin
	CGO_ENABLED=0 GOOS=linux GOARCH=${GOARCH} go build ${LDFLAGS} -o bin/${PROGRAM_NAME} ${SOURCE}

build-debug: dep ## Build pgcenter executable.
	mkdir -p ./bin
	CGO_ENABLED=0 GOOS=linux GOARCH=${GOARCH} go build ${LDFLAGS} -gcflags="all=-N -l" -o bin/${PROGRAM_NAME} ${SOURCE}

install: ## Install pgcenter executable into /usr/bin directory.
	install -pm 755 bin/${PROGRAM_NAME} /usr/bin/${PROGRAM_NAME}

uninstall: ## Uninstall pgcenter executable from /usr/bin directory.
	rm -f /usr/bin/${PROGRAM_NAME}
