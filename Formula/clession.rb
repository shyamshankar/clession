class Clession < Formula
  desc "Claude Session Manager with tmux — isolated Claude Code sessions off any branch"
  homepage "https://github.com/shyamshankar/clession"
  url "https://github.com/shyamshankar/clession/archive/refs/tags/v0.2.0.tar.gz"
  # sha256 will be filled after first release: sha256 "PLACEHOLDER"
  license "MIT"

  depends_on "git"
  depends_on "tmux"
  depends_on "gh"

  def install
    bin.install "bin/clession"
  end

  def caveats
    <<~EOS
      clession requires Claude Code (claude CLI) which is not available via Homebrew.
      Install it from: https://docs.anthropic.com/en/docs/claude-code

      Run 'clession doctor' to verify your setup.
    EOS
  end

  test do
    assert_match "clession #{version}", shell_output("#{bin}/clession --version")
  end
end
