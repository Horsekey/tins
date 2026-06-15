# GitHub Actions Vulnerabilities Demo

> **This repository intentionally contains insecure GitHub Actions workflows for educational purposes.**
> Each vulnerable pattern is paired with a corrected version. Do not use these insecure workflows into production.

This repository demonstrates the four vulnerability classes covered in the [GitHub Security Lab](https://securitylab.github.com/) GitHub Actions blog series. Browse the `.github/workflows/` directory to see both the vulnerable pattern and its fix side-by-side.

---

## Vulnerabilities

### 01 — Pwn Request (`pull_request_target` + untrusted checkout)

| File | Description |
|------|-------------|
| [`01-pwn-request-insecure.yml`](.github/workflows/01-pwn-request-insecure.yml) | Uses `pull_request_target` and checks out the PR's HEAD SHA, then runs `npm install` — giving an attacker arbitrary code execution with write access and secrets. |
| [`01-pwn-request-secure.yml`](.github/workflows/01-pwn-request-secure.yml) | Splits into an unprivileged `pull_request` workflow (runs tests, uploads artifact) and a separate `workflow_run` workflow that performs privileged actions without touching PR code. |

**Blog post:** [Keeping your GitHub Actions and workflows secure: Preventing pwn requests](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/)

---

### 02 — Script Injection via Untrusted Input

| File | Description |
|------|-------------|
| [`02-script-injection-insecure.yml`](.github/workflows/02-script-injection-insecure.yml) | Embeds `${{ github.event.issue.title }}` directly in a `run:` block. An attacker titles an issue with shell metacharacters to inject and execute arbitrary commands. |
| [`02-script-injection-secure.yml`](.github/workflows/02-script-injection-secure.yml) | Assigns the attacker-controlled value to an `env:` variable first; the shell then reads it as data, not code. |

**Blog post:** [Keeping your GitHub Actions and workflows secure: Untrusted input](https://securitylab.github.com/resources/github-actions-untrusted-input/)

---

### 03 — Supply Chain (Mutable Action References)

| File | Description |
|------|-------------|
| [`03-supply-chain-insecure.yml`](.github/workflows/03-supply-chain-insecure.yml) | References a companion action repo at `@main` — a mutable branch. The insecure workflow silently runs whatever code is currently on that branch. |
| [`03-supply-chain-secure.yml`](.github/workflows/03-supply-chain-secure.yml) | Pins to the full immutable commit SHA of the benign v1.0 release. Pushing to `@main` has no effect on this workflow. |

**This attack is live and runnable.** The insecure workflow references the companion [`github-actions-vulns-demo-action`](https://github.com/OWNER/github-actions-vulns-demo-action) repo at `@main`. To simulate a compromised maintainer:

1. Clone the companion action repo
2. Replace `action.yml` with the compromised version shown in its README
3. Push to `main`
4. Push any commit to this repo to trigger the insecure workflow
5. Check the Actions log — the malicious step runs; the secure workflow is unaffected

**Blog post:** [Keeping your GitHub Actions and workflows secure: Building blocks](https://securitylab.github.com/resources/github-actions-building-blocks/)

---

### 04 — `workflow_run` Artifact Poisoning

| File | Description |
|------|-------------|
| [`04-workflow-run-insecure.yml`](.github/workflows/04-workflow-run-insecure.yml) | A privileged `workflow_run` job downloads a PR-produced artifact and pipes it directly to `bash`. The attacker controls the artifact via their PR. |
| [`04-workflow-run-secure.yml`](.github/workflows/04-workflow-run-secure.yml) | Downloads only a plain-text PR number, validates it is an integer, then uses it as a parameter to a safe API call — never executes artifact content. |

**Blog post:** [Keeping your GitHub Actions and workflows secure: New patterns and mitigations](https://securitylab.github.com/resources/github-actions-new-patterns-and-mitigations/)

---

### 05 — IssueOps TOCTOU (`issue_comment` + mutable ref)

| File | Description |
|------|-------------|
| [`05-issueops-insecure.yml`](.github/workflows/05-issueops-insecure.yml) | Triggers on `/deploy` comments and checks out the PR's branch (a mutable ref). An attacker force-pushes malicious code after a maintainer comments but before the checkout runs. |
| [`05-issueops-secure.yml`](.github/workflows/05-issueops-secure.yml) | Uses a label-based gate. When a maintainer applies "deploy:approved", the workflow encodes the current HEAD SHA into a new label. A downstream deploy reads the SHA from the label — the TOCTOU window is eliminated. |

**Blog post:** [Keeping your GitHub Actions and workflows secure: New patterns and mitigations](https://securitylab.github.com/resources/github-actions-new-patterns-and-mitigations/)

---

## Running this demo

Workflows in this repo will trigger on real events (issue opens, PRs, comments). Since no real secrets are configured, the insecure workflows demonstrate the structural vulnerability without causing actual harm. To observe script injection (workflow 02), open an issue with a title like:

```
a"; echo "INJECTED via $(whoami)"; echo "
```

and check the Actions run log to see the injected output.

---

## Infrastructure

This repository was created with Terraform. See the source at the IaC project that provisioned it.
