.PHONY: verify-sources check-metadata test

verify-sources:
	./tools/verify-sources.sh

check-metadata:
	./tools/check-metadata.sh

test: verify-sources check-metadata
