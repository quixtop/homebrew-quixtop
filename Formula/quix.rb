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
# ⚠️ A `setup.sh` WRAPPER was explored and declined too (owner 29Aug26): fetching the script is a
# step the one-paste hub line does not have, the script cannot know the user's pairing code (the
# hub bakes it into the paste), and hiding the five commands in a file trades auditability for
# nothing. The genuine next rung down is a notarized .pkg/cask — an Apple Developer account
# question, not a script one.
#
# ⚠️ Publishable once the release exists: hashes are real (28Aug26); the URLs resolve after the
# release. Hashes below are FILLED from the version's generated SHA256SUMS-<version>.txt — never
# hand-transcribed from a separate shasum run.
#
# ⚠️ THE ORG IS `quix`, NOT `slashlabs` (owner 27Aug26). `slashlabs.cc` is a REALM — a domain the
# workers serve — and has never been a GitHub org; the two are unrelated and an install line naming
# the wrong one fails with brew's least helpful error ("no available formula").
#
# ⚠️ The tap repo MUST carry the `homebrew-` prefix: `github.com/quixtop/homebrew-quixtop`.
# brew derives the repo name from the tap name by adding it, so a repo called plain `quixtop`
# is invisible to `brew tap quixtop/quixtop; brew trust quixtop/quixtop; brew install quix`.
#
# ⚠️ RELEASES ARE HOSTED IN THE TAP REPO ITSELF, deliberately. The code lives in shrix/quix, and
# pointing the formula there would mean a second repo, a second release process, and a public
# download URL under a personal account rather than the product's org. One repo holds the formula
# and the binaries it pins; there is nothing to keep in step across two.
#
# To publish: create `github.com/quixtop/homebrew-quixtop`, drop this file in as
# `Formula/quix.rb`, attach the binaries from `bin/quix engine-build` to a release there,
# and fill in the hashes from the generated SHA256SUMS file. Then:
#     brew tap quixtop/quixtop; brew trust quixtop/quixtop; brew install quix
class Quix < Formula
  desc "Local engine for quix — Telegram and Gmail for the strm web client"
  homepage "https://quix.com"
  version "0.2.1"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/quixtop/homebrew-quixtop/releases/download/v#{version}/quix-#{version}-darwin-arm64"
      sha256 "75a232eb38c50a003243d261586067e5a4e74e2dd3867fc91a1b1bf6a889f673"
    end
    on_intel do
      url "https://github.com/quixtop/homebrew-quixtop/releases/download/v#{version}/quix-#{version}-darwin-x64"
      sha256 "a7e956001ea7419206389ad3f78ba8524e115e19c9002de9a783737a58d1e504"
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
      url "https://github.com/quixtop/homebrew-quixtop/releases/download/v#{version}/quix-#{version}-linux-arm64"
      sha256 "8ba0cfc1b2c79cd6dd3fac860d2655fa3ae2b293cc644afb1c2dc35452c6c7b1"
    end
    on_intel do
      url "https://github.com/quixtop/homebrew-quixtop/releases/download/v#{version}/quix-#{version}-linux-x64"
      sha256 "d01f17c0ce37680ed543a1d674e71a0f0f89a6e0205bf58f72420924e5df9467"
    end
  end

  def install
    # The downloaded artifact keeps its platform-stamped name; install it under the plain command.
    bin.install Dir["quix-*"].first => "quix"
    # ⚠️ EXPLICIT +x. A raw (non-archive) download arrives 0644 — there is no tarball to carry the
    # mode — and bin.install does not reliably add it. Without this the install "succeeds" and the
    # first run answers `permission denied`, which reads as a broken binary rather than a mode.
    (bin/"quix").chmod 0755
  end

  # ⚠️ A SERVICE BLOCK IS OPT-IN, NOT AUTO-START — and my first reading of this got it wrong. It was
  # omitted on the reasoning that "a launchd service would start the engine at boot on every machine
  # that installs it", which conflated HAVING the block with AUTO-STARTING: brew never starts a
  # service on install. The block only makes `brew services start quix` available, which is
  # an explicit act by the user on the machine they chose — exactly the per-device, explicit-move
  # model the on-demand design wants. Without it, macOS (the brew platform!) had no background story
  # at all while Linux/Pi had a systemd unit.
  service do
    # ⚠️ `-fg`, always. launchd supervises by watching the process it launched, and bare
    # `quix` backgrounds itself — which looks like an instant crash and gets restarted
    # forever. Most users never need this block at all: `quix` alone already backgrounds.
    run [opt_bin/"quix", "-fg"]
    # ⚠️ Restart on a CRASH, never on a clean exit. launchd has no RestartPreventExitStatus, so it
    # cannot distinguish the config-failure exit (78) the way the systemd unit does — pair BEFORE
    # starting the service, or launchd will relaunch the "not configured" message on its throttle.
    # The caveats below say so.
    keep_alive(successful_exit: false)
    log_path var/"log/quix.log"
    error_log_path var/"log/quix.log"
  end

  def caveats
    <<~EOS
      Pair this machine with your strm account — the code is in strm's Hub, on the
      Telegram or Gmail row:

        quix pair <CODE>

      Then start it. It runs in the BACKGROUND and gives the terminal back:

        quix            start          quix status     is it running?
        quix stop       stop           brew upgrade quix    get a newer build

      State (session files) is kept in:
        ~/Library/Application Support/quix     (macOS)
        ~/.local/share/quix                    (Linux)

      Override with QUIX_DATA_DIR if you want it elsewhere. An engine paired in the
      quixtop era keeps reading its old `quixtop` directory, so nothing is lost.

      This binary is unsigned. Installing through brew is what keeps macOS from
      quarantining it — downloading the same file in a browser will not work.

      RECOMMENDED: run it as a service, so it comes back after every reboot
      (owner 29Aug26 — without this, a restart leaves the engine off until you
      notice "Engine offline" in strm):
        brew services start quix      (runs `quix -fg` under launchd)
        tail -f #{var}/log/quix.log
      A bare `quix` still works for a one-off run — it backgrounds itself.

      ⚠️ Pair FIRST. launchd restarts anything that exits non-cleanly and cannot single
      out the "not configured" one, so starting the service before pairing just
      relaunches that message on a throttle. The same applies to a SESSION_KEY that
      cannot open the stored sessions — the engine refuses to start until the key is
      restored (or the session files removed), and the service would relaunch that
      refusal on the same throttle. Run `quix` by hand first; it prints the reason.
      ⚠️ Do not use BOTH `quix` and `brew services` — that is two engines.

      ⚠️ Run it on ONE machine. The hub allows a single live engine per account —
      starting a second displaces the first, which is a click you should make
      deliberately in strm's Devices panel, not by leaving two services running.
    EOS
  end

  test do
    # ⚠️ `version` is the ONE deterministic command: bare `quix` now self-daemonizes — non-TTY
    # skips the pair prompt, the child dies on config, and the parent prints the FRIENDLY line
    # (the raw "missing env" never reaches output) — and on a machine where anything answers :8080
    # it exits 0, so asserting on the daemon path fails somewhere on every real setup. Printing the
    # version still proves the cross-compiled binary loads and its runtime is intact, which is the
    # failure mode a bad cross-compile produces.
    assert_match version.to_s, shell_output("#{bin}/quix version")
  end
end
