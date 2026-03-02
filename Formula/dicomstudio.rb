# Homebrew Cask for DICOM Studio macOS Application
cask "dicomstudio" do
  version "1.0.16"
  sha256 "" # Will be filled in upon first release

  url "https://github.com/Raster-Lab/DICOMKit/releases/download/v#{version}/DICOMStudio-#{version}.dmg"
  name "DICOM Studio"
  desc "Professional macOS DICOM medical imaging workstation built with DICOMKit"
  homepage "https://github.com/Raster-Lab/DICOMKit"

  depends_on macos: ">= :sonoma"

  app "DICOMStudio.app"

  zap trash: [
    "~/Library/Preferences/com.dicomkit.DICOMStudio.plist",
    "~/Library/Caches/com.dicomkit.DICOMStudio",
    "~/Library/Saved Application State/com.dicomkit.DICOMStudio.savedState",
    "~/Library/Application Support/DICOMStudio",
  ]
end
