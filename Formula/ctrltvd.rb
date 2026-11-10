# ctrltvd — ctrlTV's Mac daemon, from quixtop's tap (ctrltv-release spec A10, FR-A9; plan T23,
# docs/spec/2026-11-02-ctrltv-release-T23-formula.md).
#
# ⚠️ PUBLISHED BY `apps formula ctrltvd <version>` (owner-run; `apps release ctrltv --promote` runs it). It takes
# `ctrltvd-<version>.tar.gz` from THIS tap's own `ctrltv-v<version>` release, checks it against that release's
# SHA256SUMS, rewrites the `url` (the version in its tag AND its filename) and `sha256` below and copies this file to
# the tap as Formula/ctrltvd.rb. The url's 0.0.0 with the all-zero hash means UNRELEASED
# (tests/welds/ctrltvd-formula.test.js).
# ⚠️ NO `version` line, and a LITERAL url (never `#{version}`): Homebrew scans the version from the url's
# filename, and `brew audit --strict` refuses an explicit `version` equal to it as redundant.
# ⚠️ Every line stays within RuboCop's 118 characters (Layout/LineLength runs under --strict) — the url and
# sha256 lines excepted (tests/welds/ctrltvd-formula.test.js).
# ⚠️ The tarball is `ctrltvd-<version>/{mac-app,config,ctrltv-<version>.apk,SHA256SUMS}` (`apps release ctrltv`).
# brew strips the top directory, so libexec holds them side by side, and its setup installs the APK from libexec
# only after checking it against that SHA256SUMS (ctrltvd/setup.py locate_apk). ctrltvd finds config/ as
# `parents[2]` of its own web.py — true only because uv installs ctrltvd EDITABLE from libexec/mac-app (uv's
# default): never add `--no-editable` / UV_NO_EDITABLE, which would put it in the venv's site-packages, where
# config/ is not.
# ⚠️ `uv run --frozen`, never a vendored venv — the quix.rb pattern (`depends_on "uv"`): uv.lock pins every
# dependency, and the environment is built on the first run under var/ (outside the Cellar, so an upgrade
# re-syncs it).
# SP-A4 (plan T59) PASSED 3Nov26: the PyPI fetch under launchd and in `brew test`, no Local Network prompt for a
# launchd-run Python (caveat: uv used Homebrew's python@3.15 — its own Python download is untested).
# ⚠️ NO post_install: Homebrew runs it sandboxed (no writes outside the prefix) and rejects new ones.
class Ctrltvd < Formula
  desc "Mac companion for ctrlTV — pairs with your Android TV and serves its dashboard"
  homepage "https://ctrl.quixtop.com"
  url "https://github.com/quixtop/homebrew-quixtop/releases/download/ctrltv-v0.1.3/ctrltvd-0.1.3.tar.gz"
  sha256 "580d530e2c2682a33c03aa188180e9194d200456b0f8de2f320524744d362049"

  # The screen reader's OCR is Apple's Vision framework (pyobjc): a Linux brew is refused here, not at the first sync.
  depends_on :macos
  depends_on "uv"

  def install
    libexec.install Dir["*"]
    # uv by its opt path (formula_opt_bin, as Homebrew/FormulaPathMethods requires under --strict): launchd's
    # PATH cannot hide it. CTRLTVD_VENV moves the environment: `brew test`'s sandbox lets a test write only temp,
    # Homebrew's cache, the formula's logs and var/{cache,log,run} — never var/ctrltvd — so the test points it
    # at testpath.
    (bin/"ctrltvd").write <<~SH
      #!/bin/bash
      export UV_PROJECT_ENVIRONMENT="${CTRLTVD_VENV:-#{var}/ctrltvd/venv}"
      exec "#{formula_opt_bin("uv")}/uv" run --frozen --no-dev --project "#{libexec}/mac-app" ctrltvd "$@"
    SH
    (bin/"ctrltvd").chmod 0755
  end

  # Opt-in, never auto-start: brew starts nothing on install (as quix.rb).
  service do
    # bare `ctrltvd` stays in the foreground, which is what launchd supervises
    run [opt_bin/"ctrltvd"]
    # restart a crash, never a clean exit; a second daemon's "port in use" (exit 3) is retried on launchd's throttle
    keep_alive successful_exit: false
    # Homebrew's bin on PATH, so adb from the android-platform-tools cask is found
    environment_variables PATH: std_service_path_env
    # the file `ctrltvd logs` tails
    log_path var/"log/ctrltvd.log"
    error_log_path var/"log/ctrltvd.log"
  end

  def caveats
    <<~EOS
      ctrltvd needs adb, which Homebrew ships as a cask (a formula cannot depend on one):
        brew install --cask android-platform-tools

      Run it as a service, so it starts at every login:
        brew services start ctrltvd
      Then open https://ctrl.quixtop.com on this Mac: it opens the dashboard and walks you
      through pairing your TV.

      The first start fetches its Python packages once (uv); later starts are quick.
      Its log:
        ctrltvd logs -f

      ⚠️ Run it ONE way: the service, or `ctrltvd` in a terminal — never both. Two
      daemons want the same port, and the second stops with "port in use".
    EOS
  end

  test do
    ENV["CTRLTVD_VENV"] = (testpath/"venv").to_s
    assert_match "ctrltvd #{version}", shell_output("#{bin}/ctrltvd --version")
  end
end
