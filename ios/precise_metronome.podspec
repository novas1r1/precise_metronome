Pod::Spec.new do |s|
  s.name             = 'precise_metronome'
  s.version          = '0.1.0'
  s.summary          = 'Sample-accurate Flutter metronome (iOS implementation).'
  s.description      = <<-DESC
Sample-accurate metronome using AVAudioEngine with procedurally synthesized
click voices. Designed for production-grade timing accuracy.
                       DESC
  s.homepage         = 'https://github.com/repeatlab/precise_metronome'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'repeatlab' => 'dev@repeatlab.de' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
