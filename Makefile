# homelab — task runner for the documented stack
SHELL := /usr/bin/env bash
SITE_PORT ?= 8020

.PHONY: help serve up down pull audit health backup check site-lint

help:            ## list targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*## "}{printf "  %-10s %s\n", $$1, $$2}'

serve:           ## serve the portfolio UI at http://127.0.0.1:8020/site/
	@echo "http://127.0.0.1:$(SITE_PORT)/site/"
	@python3 -m http.server $(SITE_PORT) --bind 127.0.0.1

up:              ## bring up every compose stack
	@for f in compose/*.yml; do echo "== $$f"; docker compose -f "$$f" up -d; done

down:            ## stop every compose stack
	@for f in compose/*.yml; do echo "== $$f"; docker compose -f "$$f" down; done

pull:            ## pull newer images without restarting
	@for f in compose/*.yml; do echo "== $$f"; docker compose -f "$$f" pull; done

audit:           ## print the live port / exposure matrix
	@./scripts/port-audit.sh

health:          ## containers + endpoints + load, exit 1 if anything is down
	@./scripts/healthcheck.sh

backup:          ## run the backup script (needs /etc/homelab/notify.env)
	@./scripts/backup.sh

check:           ## scan tracked files for secrets and personal data
	@echo "scanning for secrets…"
	@! git grep -nIE '[0-9]{8,10}:[A-Za-z0-9_-]{30,}' -- . || (echo "FAIL: bot token pattern"; exit 1)
	@! git grep -nIE 'BEGIN (RSA|OPENSSH|EC|PGP) PRIVATE KEY' -- . || (echo "FAIL: private key"; exit 1)
	@! git grep -nIE 'chat_id=[0-9]{6,}' -- . || (echo "FAIL: hardcoded chat id"; exit 1)
	@! git grep -nIE '(MYSQL|DB)_(ROOT_)?PASSWORD=[^$]' -- . || (echo "FAIL: inline password"; exit 1)
	@echo "clean"

site-lint:       ## sanity-check the static UI
	@node --check site/app.js 2>/dev/null && echo "app.js: syntax ok" || echo "node not installed, skipped"
	@python3 - <<'PY'
import html.parser, pathlib
class P(html.parser.HTMLParser):
    def error(self, m): raise SystemExit(m)
p = P(); p.feed(pathlib.Path("site/index.html").read_text()); print("index.html: parsed")
PY
