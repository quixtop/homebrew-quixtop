# AMF — the Agent Management Framework, from quixtop's tap (spec docs/spec/launcher-quixtop.md § 4.5).
#
# ⚠️ PUBLISHED BY `apps formula amf <version>` (owner-run: it needs gh auth). It rewrites the `url`
# (the version in its tag AND its filename) and `sha256` below, uploads the tarball to THIS tap's
# releases as `amf-v<version>`, and copies this file to the tap as Formula/amf.rb. The url's 0.0.0 with
# the all-zero hash means UNRELEASED — and tests/welds/amf-formula.test.js keeps the amf page `hidden`
# in PAGES for exactly as long.
# ⚠️ NO `version` line, and a LITERAL url (never `#{version}`): Homebrew scans the version from the
# url's filename, and `brew audit --strict` refuses an explicit `version` equal to it as redundant.
# ⚠️ The tarball lives in the tap's own releases because the source repo is private: Homebrew
# cannot fetch from it. Same shape as quix.rb ("releases are hosted in the tap repo itself").
# ⚠️ NO post_install: Homebrew runs it sandboxed (no writes outside the prefix, no lsregister) and
# rejects new ones. The launcher app is built by the user's own `amf launcher install`.
class Amf < Formula
  desc "Agent Management Framework — start and watch your coding agents from your Mac"
  homepage "https://amf.quixtop.com"
  url "https://github.com/quixtop/homebrew-quixtop/releases/download/amf-v0.1.0/amf-0.1.0.tar.gz"
  sha256 "86c7e3b226bde2fe9ef01bf788c842301e13ee94d827a7945bb7afef8cf9ff14"

  depends_on "bun"

  def install
    libexec.install Dir["*"]
    bin.write_exec_script libexec/"bin/amf"
  end

  def caveats
    <<~EOS
      AMF needs Claude Code installed and signed in on this Mac.

      Set up the Start button's launcher (it answers amf://start):
        amf launcher install
      Then start AMF here, or press Start on https://amf.quixtop.com:
        amf up

      `amf install` in a terminal makes AMF's offers (the chapters rule, the prompt hook).
    EOS
  end

  test do
    assert_match "AMF #{version}", shell_output("#{bin}/amf --version")
  end
end
