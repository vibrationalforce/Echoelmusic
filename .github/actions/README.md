# Custom GitHub Actions

Reusable composite actions for Echoelmusic CI/CD pipelines.

## setup-xcodegen

**Purpose:** Installs XcodeGen with binary caching for faster CI runs.

- Downloads XcodeGen from GitHub releases (default: v2.42.0)
- Caches the binary between runs (~30-40s speedup per job vs `brew install`)
- Verifies ZIP integrity before extraction
- Adds to PATH automatically

**Usage:**
```yaml
- uses: ./.github/actions/setup-xcodegen
  with:
    version: '2.42.0'  # optional, defaults to 2.42.0
```

**Used by:** ci.yml, testflight.yml, pr-check.yml, phase8000-ci.yml

---

## setup-asc-api-key

**Purpose:** Configures App Store Connect API key for xcodebuild authentication.

- Handles both base64-encoded and raw .p8 key content
- Writes key file to `~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8`
- Validates PEM format (checks for `BEGIN PRIVATE KEY` header)
- Outputs the key file path for use in subsequent steps

**Usage:**
```yaml
- uses: ./.github/actions/setup-asc-api-key
  with:
    key-id: ${{ secrets.APP_STORE_CONNECT_KEY_ID }}
    key-content: ${{ secrets.APP_STORE_CONNECT_PRIVATE_KEY }}
```

**Outputs:**
- `key-path`: Absolute path to the configured .p8 key file

**Used by:** testflight.yml (currently inlined, action available for future refactoring)

---

## Security Notes

- API keys are written with `chmod 600` (owner-only read/write)
- Keys are stored in runner-local paths, cleaned up after each job
- Never commit actual key values - always use GitHub Secrets
