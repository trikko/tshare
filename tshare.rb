class Tshare < Formula
  desc "Share files from CLI, using transfer.sh"
  homepage "https://github.com/trikko/tshare"
  url "https://github.com/trikko/tshare/archive/refs/tags/v1.0.5.tar.gz"
  sha256 "d89a209654942360c1d9bebf1b0b65c062686b213425fcf6df8466d1dd6613f8"
  license "MIT"
  head "https://github.com/trikko/tshare.git", branch: "main"

  depends_on "dub" => :build
  depends_on "ldc" => :build

  link_overwrite "bin/tshare"

  def install
    system "dub", "build", "--compiler=ldc2", "--build=release"
    bin.install "tshare"
  end

  test do
    assert_equal "tshare/1.0 (https://github.com/trikko/tshare)", shell_output("#{bin}/tshare --version").chomp
  end
end
