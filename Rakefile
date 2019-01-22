require 'digest/sha2'
require "yaml"
require 'pp'

require "google/cloud/text_to_speech"

# Quilck Reference for Rakefile:
# https://gist.github.com/noonat/1649543

def load_filter
  Dir.glob("filter/*.rb") do |filename|
    load(filename)
  end
end
load_filter

def say(voice, content)
  options = { name: voice, language_code: voice[0..4] }
  synthesis_input = { text: content }
  audio_config = { audio_encoding: "LINEAR16" }
  client = Google::Cloud::TextToSpeech.new
  result = client.synthesize_speech synthesis_input, options, audio_config
  result.audio_content
end

# out/svl/mix/svl-en_ja_en--svl-01.mp3
# out/svl/mp3/svl-en_ja_en--svl-01.mp3
# out/svl/compile/svl-en_ja_en--svl-01.wav
# out/svl/concat/svl-en_ja_en--svl-01--0001.wav
# out/svl/concat/svl-en_ja_en--svl-01--0002.wav
# out/svl/raw/ca978112...ee48bb.wav
# out/svl/raw/09e62852...3e05ef.wav
# out/svl/raw/b0ad6bc1...b11365.wav
# out/svl/raw/f47a89d2...a2ceb7.wav

task :noop
task default: :noop

CONFIG_DIR = File.dirname(File.expand_path(ENV["conf"]))
CONFIG = YAML.load_file(ENV["conf"])
ROOT = "out/#{CONFIG["project"]}"
DIR = {
  raw: "#{ROOT}/raw",
  silent: "#{ROOT}/silent",
  concat: "#{ROOT}/concat",
  compile: "#{ROOT}/compile",
  mp3: "#{ROOT}/mp3",
  mix: "#{ROOT}/mix",
}

def build_filelist(source_file, rule_name)
  basename = source_file.pathmap('%n') # base name without ext
  prefix = "#{CONFIG["project"]}-#{rule_name}--#{basename}"

  filelist = {
    source: source_file,
    mix: "#{DIR[:mix]}/#{prefix}.mp3",
    mp3: "#{DIR[:mp3]}/#{prefix}.mp3",
    compile: "#{DIR[:compile]}/#{prefix}.wav",
    concat: [],
    raw: [],
    say_args_by_raw: {},
    silent_by_duration: {}
  }

  required_fields = CONFIG['concat'][rule_name].uniq
  required_fields.select { |d| d.is_a?(Numeric) }.each do |duration|
    filelist[:silent_by_duration][duration] = "#{DIR[:silent]}/#{duration}.wav"
  end

  File.readlines(source_file).each_with_index do |line, index|
    line.chomp!

    filelist[:concat] << "#{DIR[:concat]}/#{prefix}--#{'%04d' % (index + 1)}.wav"
    fields = CONFIG['fields'].to_a
    raw_by_field = {}

    line.split(/\t/).each_with_index do |content, index|
      field, voice = fields[index]
      next unless voice
      filter = CONFIG['filter'][field]
      content = Filter.send(filter, content) if filter

      digest = Digest::SHA256.hexdigest(voice + content)
      raw_file = "#{DIR[:raw]}/#{digest}.wav"
      filelist[:say_args_by_raw][raw_file] = [voice, content]
      raw_by_field[field] = raw_file
    end
    filelist[:raw] << raw_by_field
  end
  filelist
end

def define_task(filelist, rule_name)
  namespace rule_name do
    desc "debug"
    task :debug do
      pp filelist
    end

    desc "itunes"
    task itunes: [:album] do
      artist = CONFIG['album'][rule_name]['artist']
      title = CONFIG['album'][rule_name]['title']
      music_dir = File.join(ENV['HOME'], "Music/iTunes/iTunes Music/Music")
      if artist and title
        album_dir = File.join(music_dir, artist, title)
        if File.directory?(album_dir)
          target_dir = album_dir
        else
          target_dir = File.join(music_dir, "Automatically Add to iTunes")
        end
        cp filelist[:mix], target_dir, verbose: true
      end
    end

    # album
    #----------------
    desc "album"
    task album: filelist[:mix] do |t|
      options = []
      if artist = CONFIG['album'][rule_name]['artist']
        options << "-a #{artist}"
      end
      if title = CONFIG['album'][rule_name]['title']
        options << "-A #{title}"
      end
      if jacket = CONFIG['album'][rule_name]['jacket']
        options << "--add-image #{File.join(CONFIG_DIR, jacket)}:FRONT_COVER"
      end

      sh "eyeD3 #{options.join(' ')} --add-lyrics #{filelist[:source]} #{t.source}"
    end

    # mix
    #----------------
    file filelist[:mix] => filelist[:mp3] do |t|
      mkdir_p DIR[:mix], verbose: false

      mix_muic = ENV['mix']
      if mix_muic
        duration=`soxi #{t.source} | grep Duration | awk '{ print $3 }'`.chomp
        sh "sox #{t.source} -m #{mix_muic} #{t.name} trim 00:00.00 #{duration} fade 0 -0 6"
      else
        warn "you need to pass 'mix' env var"
      end
    end

    desc "mix"
    task mix: filelist[:mix]

    # mp3
    #----------------
    file filelist[:mp3] => filelist[:compile] do |t|
      mkdir_p DIR[:mp3], verbose: false
      sh "ffmpeg -loglevel quiet -i #{t.source} -vn -ac 2 -ar 44100 -ab 256k -acodec libmp3lame -f mp3 #{t.name}"
    end

    desc "mp3"
    task mp3: filelist[:mp3]

    # compile
    #----------------
    file filelist[:compile] => filelist[:concat] do |t|
      mkdir_p DIR[:compile], verbose: false
      sh "sox #{t.sources.join(" ")} #{t.name} pad 0 7" # pad with 7s silence at end.
    end

    desc "compile"
    task compile: filelist[:compile]

    # concat
    #----------------
    filelist[:concat].each_with_index do |concat_file, index|
      raw_file_by_field = filelist[:raw][index]

      depends = raw_file_by_field.values + filelist[:silent_by_duration].values()
      file concat_file => depends do |t|
        mkdir_p DIR[:concat], verbose: false
        files = CONFIG['concat'][rule_name].map { |field|
          raw_file_by_field[field] || filelist[:silent_by_duration][field]
        }
        sh "sox #{files.join(" ")} #{t.name}"
      end
    end

    desc "concat"
    task concat: filelist[:concat]

    #----------------
    desc "raw"
    task raw: filelist[:say_args_by_raw].keys

    # play
    #----------------
    namespace :play do
      def play(file)
        tempo = ENV['tempo']
        cmd = "play -q #{file}"
        cmd += " tempo #{tempo}" if tempo
        sh cmd
      end

      desc "mix"
      task :mix do
        play filelist[:mix]
      end

      desc "mp3"
      task :mp3 do
        play filelist[:mp3]
      end

      desc "compile"
      task :compile do
        play filelist[:compile]
      end

      desc "concat"
      task :concat, [:line] do |t, args|
        line = args[:line].to_i
        play(filelist[:concat][line - 1]) if line > 0
      end

      desc "raw"
      task :raw, [:line, :field] do |t, args|
        line = args[:line].to_i
        play filelist[:raw][line - 1][args[:field]] if line > 0
      end
    end
  end
end

all_files = {
  mp3: [],
  mix: [],
  compile: [],
  concat: [],
  silent: [],
  raw: [],
  say_args_by_raw: {},
}

CONFIG['concat'].keys.each do |rule_name|
  filelist = build_filelist(ENV['src'], rule_name)
  all_files[:mp3] << filelist[:mp3]
  all_files[:mix] << filelist[:mix]
  all_files[:compile] << filelist[:compile]
  all_files[:concat].concat(filelist[:concat])
  all_files[:raw].concat(filelist[:say_args_by_raw].keys)
  all_files[:say_args_by_raw].merge!(filelist[:say_args_by_raw])

  define_task(filelist, rule_name)
end

all_files[:raw].uniq!

# silent
#----------------
rule %r{#{ROOT}/silent/.*} do |t|
  mkdir_p DIR[:silent], verbose: false
  # Silent flename is just duration.  ex) out/svl/silent/1.0.wav
  duration = t.name.pathmap('%n')
  sh "sox -n #{t.name} trim 0 #{duration} rate 24000"
end

# raw
#----------------
all_files[:say_args_by_raw].each do |raw_file, say_args|
  file raw_file do
    mkdir_p DIR[:raw], verbose: false
    File.write(raw_file, say(*say_args), mode: "wb")
    puts "GOT: #{content}, #{raw_file}"
  end
end

namespace :clean do
  extname = File.extname(ENV['src'])
  basename = File.basename(ENV['src'], extname)

  desc "raw_unused"
  task :raw_unused do
    actual = Dir.glob("#{DIR[:raw]}/#{basename}--*")
    unused = actual - all_files[:raw]
    rm unused, verbose: true unless unused.empty?
  end

  desc "except_raw"
  task :except_raw do
    rm_rf DIR[:mix]
    rm_rf DIR[:mp3]
    rm_rf DIR[:compile]
    rm_rf DIR[:concat]
    rm_rf DIR[:silent]
  end
end
