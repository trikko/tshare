class Tshare < Formula
  desc "Share files from CLI, using transfer.sh"
  homepage "https://github.com/trikko/tshare"
  url "https://github.com/trikko/tshare/archive/refs/tags/v1.1.0.tar.gz"
  sha256 "f6e30a4968af5d6bde76d9fed218669d6c1e23e35a642d1080e9e094e769d997"
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
