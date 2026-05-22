# SECURE: Pinned SHA + no blanket secret exposure to third-party steps
#
# Two fixes applied:
# 1. The action is pinned to an immutable full commit SHA — even if a maintainer
#    pushes malicious code to @main, this workflow runs the original reviewed commit.
# 2. No VARIABLE_STORE env var at the job level — secrets are never dumped into
#    the environment of third-party steps. If a step genuinely needs a secret,
#    pass only that specific secret scoped to that one step.
#
# Use Dependabot or `pin-github-action` to keep SHAs current as new versions ship.

name: "[SECURE] 03 - Supply Chain (Pinned SHA)"

on: push

jobs:
  build:
    runs-on: ubuntu-latest
    # No VARIABLE_STORE here — third-party actions never see a secrets dump
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      # Pinned to the benign v1.0 commit — immune to upstream changes
      - uses: ${owner}/${action_repo}@${benign_sha}  # benign v1.0
