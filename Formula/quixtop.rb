# Homebrew formula for the strm engine.
#
# ⚠️ THIS IS THE DISTRIBUTION DECISION, not a convenience wrapper (27Aug26). The engine binary is
# UNSIGNED and un-notarized. macOS attaches a quarantine attribute to anything a BROWSER downloads,
# and Gatekeeper then refuses to run it — so a plain "download the binary" link is broken on every
# Mac unless we buy an Apple Developer account and build a notarization pipeline. `brew` fetches
# over curl, which sets no quarantine attribute, so the same file installs and runs untouched.
# That is why distribution goes through a tap rather than a release link or `curl | sh`.
#
# ⚠️ `curl | sh` was considered and REJECTED. It solves nothing Gatekeeper-wise (the script still has
# to place a binary), and piping a remote script into a shell contradicts what this project enforces
# everywhere else — SSRF guards at 21 call sites, sealed keys at rest, a refusal to dial cleartext.
#
# ⚠️ Publishable once the release exists: hashes are real (28Aug26); the URLs resolve after the
# release. Hashes below are FILLED from the generated SHA256SUMS-0.1.0.txt (28Aug26) — never
# hand-transcribed from a separate shasum run.
#
# ⚠️ THE ORG IS `quixtop`, NOT `slashlabs` (owner 27Aug26). `slashlabs.cc` is a REALM — a domain the
# workers serve — and has never been a GitHub org; the two are unrelated and an install line naming
# the wrong one fails with brew's least helpful error ("no available formula").
#
# ⚠️ The tap repo MUST carry the `homebrew-` prefix: `github.com/quixtop/homebrew-quixtop`.
# brew derives the repo name from the tap name by adding it, so a repo called plain `quixtop`
# is invisible to `brew tap quixtop/quixtop && brew trust quixtop/quixtop && brew install quixtop`.
#
# ⚠️ RELEASES ARE HOSTED IN THE TAP REPO ITSELF, deliberately. The code lives in shrix/quixtop, and
# pointing the formula there would mean a second repo, a second release process, and a public
# download URL under a personal account rather than the product's org. One repo holds the formula
# and the binaries it pins; there is nothing to keep in step across two.
#
# To publish: create `github.com/quixtop/homebrew-quixtop`, drop this file in as
# `Formula/quixtop.rb`, attach the binaries from `bin/quix engine-build` to a release there,
# and fill in the hashes from the generated SHA256SUMS file. Then:
#     brew tap quixtop/quixtop && brew trust quixtop/quixtop && brew install quixtop
class Quixtop < Formula
  desc "Local engine for quix — Telegram and Gmail for the strm web client"
  homepage "https://quixtop.com"
  version "0.1.1"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/quixtop/homebrew-quixtop/releases/download/v#{version}/quixtop-#{version}-darwin-arm64"
      sha256 "3dd61d345cce75be43c098782c873f4bb5e67cb947c0fddffa5dfdab337f1ca5"
    end
    on_intel do
      url "https://github.com/quixtop/homebrew-quixtop/releases/download/v#{version}/quixtop-#{version}-darwin-x64"
      sha256 "c8e14e95d2a4b35e6f207a0e27d28da8d0bb67c5cef7eacb41c98595b35f91d1"
    end
  end

  # ⚠️ ARCH-BRANCHED, like macOS. brew is the MAC path by decision (Linux/Windows use the direct
  # download), but Homebrew does run on Linux and an unbranched block would hand a Raspberry Pi the
  # x64 binary — which fails at exec with a message that explains nothing.
  # ⚠️ Homebrew on Linux may not support arm64 at all; if so this block simply never fires, which is
  # harmless. It is here so that a Pi is never served the WRONG artifact, not to promise brew works
  # there — the Pi's supported path is the direct download.
  on_linux do
    on_arm do
      url "https://github.com/quixtop/homebrew-quixtop/releases/download/v#{version}/quixtop-#{version}-linux-arm64"
      sha256 "4fe2807c45426ac32d040669538bda4b37aba1c94121e6c93877b78ed7b44345"
    end
    on_intel do
      url "https://github.com/quixtop/homebrew-quixtop/releases/download/v#{version}/quixtop-#{version}-linux-x64"
      sha256 "0a66c1377b321499369fa57ceb85a2cf8ff3d2987f88a2ad2fa9808376357fc7"
    end
  end

  def install
    # The downloaded artifact keeps its platform-stamped name; install it under the plain command.
    bin.install Dir["quixtop-*"].first => "quixtop"
    # ⚠️ EXPLICIT +x. A raw (non-archive) download arrives 0644 — there is no tarball to carry the
    # mode — and bin.install does not reliably add it. Without this the install "succeeds" and the
    # first run answers `permission denied`, which reads as a broken binary rather than a mode.
    (bin/"quixtop").chmod 0755
  end

  # ⚠️ A SERVICE BLOCK IS OPT-IN, NOT AUTO-START — and my first reading of this got it wrong. It was
  # omitted on the reasoning that "a launchd service would start the engine at boot on every machine
  # that installs it", which conflated HAVING the block with AUTO-STARTING: brew never starts a
  # service on install. The block only makes `brew services start quixtop` available, which is
  # an explicit act by the user on the machine they chose — exactly the per-device, explicit-move
  # model the on-demand design wants. Without it, macOS (the brew platform!) had no background story
  # at all while Linux/Pi had a systemd unit.
  service do
    # ⚠️ `-fg`, always. launchd supervises by watching the process it launched, and bare
    # `quixtop` backgrounds itself — which looks like an instant crash and gets restarted
    # forever. Most users never need this block at all: `quixtop` alone already backgrounds.
    run [opt_bin/"quixtop", "-fg"]
    # ⚠️ Restart on a CRASH, never on a clean exit. launchd has no RestartPreventExitStatus, so it
    # cannot distinguish the config-failure exit (78) the way the systemd unit does — pair BEFORE
    # starting the service, or launchd will relaunch the "not configured" message on its throttle.
    # The caveats below say so.
    keep_alive(successful_exit: false)
    log_path var/"log/quixtop.log"
    error_log_path var/"log/quixtop.log"
  end

  def caveats
    <<~EOS
      Pair this machine with your strm account — the code is in strm's Hub, on the
      Telegram or Gmail row:

        quixtop pair <CODE>

      Then start it. It runs in the BACKGROUND and gives the terminal back:

        quixtop            start          quixtop status     is it running?
        quixtop stop       stop           quixtop update     get a newer build

      State (session files) is kept in:
        ~/Library/Application Support/quixtop     (macOS)
        ~/.local/share/quixtop                    (Linux)

      Override with QUIX_DATA_DIR if you want it elsewhere. An engine paired before
      the 28Aug26 rename keeps reading its old `quix` directory, so nothing is lost.

      This binary is unsigned. Installing through brew is what keeps macOS from
      quarantining it — downloading the same file in a browser will not work.

      `quixtop` already backgrounds itself, so you do NOT need brew services. Use it
      only if you also want the engine to come back automatically after a reboot:
        brew services start quixtop      (runs `quixtop -fg` under launchd)
        tail -f #{var}/log/quixtop.log

      ⚠️ Pair FIRST. launchd restarts anything that exits non-cleanly and cannot single
      out the "not configured" one, so starting the service before pairing just
      relaunches that message on a throttle.
      ⚠️ Do not use BOTH `quixtop` and `brew services` — that is two engines.

      ⚠️ Run it on ONE machine. The hub allows a single live engine per account —
      starting a second displaces the first, which is a click you should make
      deliberately in strm's Devices panel, not by leaving two services running.
    EOS
  end

  test do
    # ⚠️ Asserts it STARTS and reaches its own config check, not that it connects: a test that needs
    # Telegram credentials cannot run in Homebrew's CI, and one that needs the network is flaky by
    # construction. Reaching "missing env" proves the binary loaded and its runtime is intact —
    # which is the exact failure mode a bad cross-compile produces.
    output = shell_output("#{bin}/quixtop 2>&1", 1)
    assert_match "missing env", output
  end
end
