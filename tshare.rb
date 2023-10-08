class Tshare < Formula
  desc "Share files from CLI, using transfer.sh"
  homepage "https://github.com/trikko/tshare"
  url "https://github.com/trikko/tshare/archive/refs/tags/v1.0.6.tar.gz"
  sha256 "e7729ec97ed7c174aaf8d33a7d7a53f53690792a27558cb33651fd81cdc14bcd"
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
    assert_equal "tshare/1.1 (https://github.com/trikko/tshare)", shell_output("#{bin}/tshare --version").chomp
  end
end
