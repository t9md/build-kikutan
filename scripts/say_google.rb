#!/usr/bin/env ruby
require "google/cloud/text_to_speech"
require 'optparse'
require "pp"

def say(synthesis_input, voice)
  client = Google::Cloud::TextToSpeech.new
  audio_config = { audio_encoding: "LINEAR16" }
  response = client.synthesize_speech synthesis_input, voice, audio_config
  response.audio_content
end

options = {}
$play = false
$ssml = false
OptionParser.new do |opts|
  basename = File.basename(__FILE__)
  opts.banner = "Usage: #{basename} [options]"
  opts.on("-c", "--check", "Check option") { |v| options[:check] = v }
  opts.on("-s", "--ssml", "Use SSML") { |v| $ssml = v }
  opts.on("-v", "--voice-name=name", "Voice Name") { |v| options[:name] = v }
  opts.on("-p", "--play", "Play") { |v| $play = v }
end.parse!

text_to_speech = ARGV[0] || ARGF.read
default_options_Ja = { language_code: "ja-JP", name: "ja-JP-Standard-A" }
# default_options_Ja = { language_code: "ja-JP", name: "ja-JP-Wavenet-A" }
default_options_En = { language_code: "en-US", name: "en-US-Standard-B" }

if text_to_speech =~  /(?:\p{Hiragana}|\p{Katakana}|[一-龠々])/
  default_options = default_options_Ja
else
  default_options = default_options_En
end

voice_options = default_options.merge(options)
if options[:check]
  pp voice_options
  exit 0
end

if ($ssml)
  result = say({ssml: text_to_speech}, voice_options)
else
  result = say({text: text_to_speech}, voice_options)
end

if $play
  IO.popen("play -t wav -", "r+") do |io|
    io.puts result
  end
else
  print result
end
