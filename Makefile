.PHONY: verify-sources check-metadata test build-baseline distrobox-smoke

verify-sources:
	./tools/verify-sources.sh

check-metadata:
	./tools/check-metadata.sh

test: verify-sources check-metadata

build-baseline:
	@test -n "$(OUTPUT)" || { echo 'usage: make build-baseline OUTPUT=/absolute/output/path' >&2; exit 64; }
	./tools/build-baseline-container.sh "$(OUTPUT)"

distrobox-smoke:
	@if test -n "$(OUTPUT)"; then ./tools/smoke-baseline-distrobox.sh "$(OUTPUT)"; else ./tools/smoke-baseline-distrobox.sh; fi
