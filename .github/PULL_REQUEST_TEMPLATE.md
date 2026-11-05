## Summary
What changed and why.

## Testing
Commands run and their results (paste output or say "not run" with reason):

```sh
flutter test
flutter analyze --no-fatal-infos
```

## Risk
- [ ] Low — docs, comments, tests only
- [ ] Medium — app logic with existing test coverage
- [ ] High — auth, seed/mnemonic, payments, alerts, CI, signing, dependencies

## Security checklist
- [ ] No credentials, private keys, service-role tokens, or user data added
- [ ] Mnemonic / seed material is not logged, committed, or sent to a server
- [ ] No lint, test, or CI check was disabled to make this pass

## How to revert
One-liner or `git revert <sha>`.
