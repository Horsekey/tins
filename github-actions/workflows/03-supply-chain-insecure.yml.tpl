# INSECURE: Mutable action reference (@main branch pin)
#
# Vulnerability: This workflow references a third-party action at @main — a branch
# that changes with every commit. If the action maintainer is compromised (or IS an
# attacker), they push malicious code to main and every workflow using @main silently
# runs it on the next trigger — no reference change visible to the caller.
#
# To see this attack live:
#   1. Go to ${owner}/${action_repo} and follow the README instructions to push
#      the "compromised" version of action.yml to main.
#   2. Push any commit to this repo to retrigger this workflow.
#   3. Check the Actions log — the compromised step will execute instead of the benign one.

name: "[INSECURE] 03 - Supply Chain (Mutable Action Ref)"

on: push

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      # DANGER: dumps every secret into an env var visible to ALL steps in this job,
      # including the third-party action below. A compromised action reads $VARIABLE_STORE
      # and uploads it as an artifact — exfiltrating every secret in one move.
      VARIABLE_STORE: $${{ toJSON(secrets) }}
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      # DANGER: @main changes on every upstream commit — caller has no control
      # over what code actually runs here after the action repo is "compromised"
      - uses: ${owner}/${action_repo}@main
