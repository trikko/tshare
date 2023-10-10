class Tshare < Formula
  desc "Share files from CLI, using transfer.sh"
  homepage "https://github.com/trikko/tshare"
  url "https://github.com/trikko/tshare/archive/refs/tags/v1.1.3.tar.gz"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
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
