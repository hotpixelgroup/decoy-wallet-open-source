# backend/AGENTS.md

Read the root [AGENTS.md](../AGENTS.md) first. Extra rules for this directory:

- These scripts are **helpers and tests** for operators. They are not a full
  production payment service.
- **No npm dependencies.** Prefer Node built-ins only. Do not add `package.json`
  or third-party packages without maintainer approval.
- Secrets come from the environment (`SUPABASE_SERVICE_ROLE_KEY`, Stripe keys,
  peppers). Never hardcode them; never commit `.env` or canary outputs.
- Do **not** run `*.command` deploy scripts, production smoke/canary scripts, or
  anything that mutates staging/production from an agent session unless the
  maintainer named the exact script and environment.
- Safe default verify:

```sh
node --test backend/membership_redemption/*.test.mjs
```

- `account_deletion` tests need an optional PGlite module; follow
  `account_deletion/README.md` rather than inventing a runner.
