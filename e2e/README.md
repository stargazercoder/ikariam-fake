# ikariam-fake — E2E tests

Playwright E2E tests for ikariam-fake.

## Run

```bash
# default baseURL is http://localhost:8080
playwright test

# against staging
E2E_BASE_URL=https://staging.example.com playwright test

# headed (visible browser, requires X / xvfb on VPS)
playwright test --headed

# UI mode
playwright test --ui
```

Global Playwright install on this VPS — no `npm install` needed.

## Reports

```bash
playwright show-report
```
