.PHONY: test smoke regression extension

test: smoke regression extension

smoke:
	./tests/smoke.sh

regression:
	./tests/regression.sh

extension:
	@if node -e 'process.exit(Number(process.versions.node.split(".")[0]) >= 22 ? 0 : 1)'; then \
		node --experimental-strip-types --check extensions/continuum.ts && \
		node --experimental-strip-types tests/extension.test.mjs; \
	else \
		echo "SKIP: Node 22+ required for the TypeScript checks"; \
	fi
