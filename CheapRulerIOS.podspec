Pod::Spec.new do |s|
  s.name             = "CheapRulerIOS"
  s.version          = "0.1.0"
  s.summary          = "Swift port of https://github.com/mapbox/cheap-ruler"

  s.description      = <<-DESC
Swift port of cheap-ruler by @mourner, @anandthakker, @tcql and mapbox (https://github.com/mapbox/cheap-ruler). Check out their repo for details.
                       DESC

  s.homepage         = "https://github.com/iThinker/CheapRulerIOS"
  s.license          = 'MIT'
  s.author           = { "Roman Temchenko" => "temchenko.r@gmail.com" }
  s.source           = { :git => "https://github.com/iThinker/CheapRulerIOS.git", :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'

  s.source_files = 'CheapRulerIOS/Classes/**/*'

  s.frameworks = 'CoreLocation'
end
