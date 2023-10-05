class Tshare < Formula
  desc "Share files from CLI, using transfer.sh"
  homepage "https://github.com/trikko/tshare"
  url "https://github.com/trikko/tshare/archive/refs/tags/v1.0.4.tar.gz"
  sha256 "4c37ac39b3a76acdb728875cedf01129a60444a508835de2016c897ab8aba09b"
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
