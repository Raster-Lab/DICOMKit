# Homebrew Formula for DICOMKit CLI Tools
class Dicomkit < Formula
  desc "Pure Swift DICOM toolkit with 29 command-line utilities"
  homepage "https://github.com/Raster-Lab/DICOMKit"
  url "https://github.com/Raster-Lab/DICOMKit/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "" # Will be filled in upon first release
  license "MIT"
  head "https://github.com/Raster-Lab/DICOMKit.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on macos: :sonoma

  def install
    # Build all CLI tools using Swift Package Manager
    system "swift", "build", "-c", "release", "--disable-sandbox"
    
    # Install all 29 CLI executables
    cli_tools = [
      "dicom-info", "dicom-convert", "dicom-validate", "dicom-anon", "dicom-dump",
      "dicom-query", "dicom-send", "dicom-diff", "dicom-retrieve", "dicom-split",
      "dicom-merge", "dicom-json", "dicom-xml", "dicom-pdf", "dicom-image",
      "dicom-dcmdir", "dicom-archive", "dicom-export", "dicom-qr", "dicom-wado",
      "dicom-echo", "dicom-mwl", "dicom-mpps", "dicom-pixedit", "dicom-tags",
      "dicom-uid", "dicom-compress", "dicom-study", "dicom-script"
    ]
    
    cli_tools.each do |tool|
      bin.install ".build/release/#{tool}"
    end
    
    # Install documentation
    doc.install "README.md", "CHANGELOG.md", "LICENSE"
    doc.install "Documentation" if File.directory?("Documentation")
  end

  test do
    # Test a few representative CLI tools
    assert_match "DICOMKit", shell_output("#{bin}/dicom-info --version 2>&1")
    assert_match "Usage:", shell_output("#{bin}/dicom-convert --help")
    assert_match "DICOM", shell_output("#{bin}/dicom-validate --help")
  end
end
