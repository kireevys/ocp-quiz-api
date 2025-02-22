ifeq ($(DB_DSN),)
DB_DSN := "postgres://postgres:postgres@0.0.0.0:5432/postgres?sslmode=disable"
endif

.PHONY: build
build: vendor-proto .generate .build

.PHONY: .generate
.generate:
		mkdir -p swagger
		mkdir -p pkg/ocp-quiz-api
		protoc -I vendor.protogen \
				--go_out=pkg/ocp-quiz-api --go_opt=paths=import \
				--go-grpc_out=pkg/ocp-quiz-api --go-grpc_opt=paths=import \
				--grpc-gateway_out=pkg/ocp-quiz-api \
				--grpc-gateway_opt=logtostderr=true \
				--grpc-gateway_opt=paths=import \
				--swagger_out=allow_merge=true,merge_file_name=api:swagger \
				--validate_out lang=go:pkg/ocp-quiz-api \
				api/ocp-quiz-api/ocp_quiz_api.proto
		mv pkg/ocp-quiz-api/github.com/ozoncp/ocp-quiz-api/pkg/ocp-quiz-api/* pkg/ocp-quiz-api/
		rm -rf pkg/ocp-quiz-api/github.com
		mkdir -p cmd/ocp-quiz-api
		cd pkg/ocp-quiz-api && ls go.mod || go mod init github.com/ozoncp/ocp-quiz-api/pkg/ocp-quiz-api && go mod tidy

.PHONY: .build
.build:
		CGO_ENABLED=0 GOOS=linux go build -o bin/ocp-quiz-api cmd/ocp-quiz-api/main.go

.PHONY: install
install: build .install

.PHONY: .install
install:
		go install cmd/grpc-server/main.go

.PHONY: vendor-proto
vendor-proto: .vendor-proto

.PHONY: .vendor-proto
.vendor-proto:
		mkdir -p vendor.protogen
		mkdir -p vendor.protogen/api/ocp-quiz-api
		cp api/ocp-quiz-api/ocp_quiz_api.proto vendor.protogen/api/ocp-quiz-api
		@if [ ! -d vendor.protogen/google ]; then \
			git clone https://github.com/googleapis/googleapis vendor.protogen/googleapis &&\
			mkdir -p  vendor.protogen/google/ &&\
			mv vendor.protogen/googleapis/google/api vendor.protogen/google &&\
			rm -rf vendor.protogen/googleapis ;\
		fi
		@if [ ! -d vendor.protogen/github.com/envoyproxy ]; then \
			mkdir -p vendor.protogen/github.com/envoyproxy &&\
			git clone https://github.com/envoyproxy/protoc-gen-validate vendor.protogen/github.com/envoyproxy/protoc-gen-validate ;\
		fi


.PHONY: deps
deps: install-go-deps

.PHONY: install-go-deps
install-go-deps: .install-go-deps

.PHONY: .install-go-deps
.install-go-deps:
		ls go.mod || go mod init
		go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway@v1.16.0
		go get -u github.com/golang/protobuf/proto
		go get -u github.com/golang/protobuf/protoc-gen-go
		go get -u google.golang.org/grpc@v1.40.0
		go get -u google.golang.org/grpc/cmd/protoc-gen-go-grpc
		go get -u github.com/envoyproxy/protoc-gen-validate
		go install google.golang.org/grpc/cmd/protoc-gen-go-grpc
		go install github.com/grpc-ecosystem/grpc-gateway/protoc-gen-swagger
		go install github.com/envoyproxy/protoc-gen-validate

.PHONY: migrate
migrate: .install-migrate-deps .migrate

.PHONY: .install-migrate-deps
.install-migrate-deps:
		go get -u github.com/pressly/goose/v3/cmd/goose

.PHONY: .migrate
.migrate:
		goose -dir sql-migrations postgres $(DB_DSN) up