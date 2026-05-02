.PHONY: lint test shellcheck format-check pycompile selftest ci

lint:
	ruff check .

shellcheck:
	bash -n install.sh
	find scripts tools -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
	shellcheck -x install.sh scripts/*.sh scripts/lib/*.sh tools/*.sh

format-check:
	shfmt -d install.sh scripts tools

pycompile:
	python3 -m py_compile start_suite.py

selftest:
	bash scripts/repo_selftest.sh

test:
	pytest -q

ci: shellcheck format-check pycompile selftest lint test
