# Verze OpenCV.js musí odpovídat OPENCV_VERSION v Makefile.
module SolutionScan
  OPENCV_JS = '/javascripts/opencv-4.13.0.js'.freeze

  def self.scanner_js
    "/javascripts/scanner.js?v=#{File.mtime(Rails.public_path.join('javascripts', 'scanner.js')).to_i}"
  end
end
