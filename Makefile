.PHONY: bootstrap build-client check-server run run-prod run-local open-xcode

bootstrap:
	./scripts/bootstrap.sh

build-client:
	cd client-swift && swift build

check-server:
	cd spacetimedb && cargo check

run:
	./scripts/publish-prod.sh

run-prod:
	./scripts/publish-prod.sh

run-local:
	./scripts/run-local.sh

open-xcode:
	cd client-swift && open Package.swift
