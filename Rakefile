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

def say(text, options)
  options[:language_code] = options[:name][0..4]
  synthesis_input = { text: text }
  audio_config = { audio_encoding: "LINEAR16" }
  client = Google::Cloud::TextToSpeech.new
  client.synthesize_speech synthesis_input, options, audio_config
end

# out/svl/mix/svl-en_ja_en--svl-01.mp3
# out/svl/mp3/svl-en_ja_en--svl-01.mp3
# out/svl/compile/svl-en_ja_en--svl-01.wav
# out/svl/concat/en_ja_en--svl-01--0001.wav
# out/svl/concat/en_ja_en--svl-01--0002.wav
# out/svl/raw/svl-01--0001-en-ca978112...ee48bb.wav
# out/svl/raw/svl-01--0001-ja-09e62852...3e05ef.wav
# out/svl/raw/svl-01--0002-en-b0ad6bc1...b11365.wav
# out/svl/raw/svl-01--0002-ja-f47a89d2...a2ceb7.wav
def file_for(kind, opts)
  dir = DIR[kind]
  project = CONFIG["project"]
  rule_name = opts[:rule_name]
  basename = opts[:basename]
  case kind
  when :mix, :mp3 then
    "#{dir}/#{project}-#{rule_name}--#{basename}.mp3"
  when :compile
    "#{dir}/#{project}-#{rule_name}--#{basename}.wav"
  when :concat
    "#{dir}/#{rule_name}--#{basename}--#{opts[:lineno]}.wav"
  when :raw
    "#{dir}/#{basename}--#{opts[:lineno]}-#{opts[:field]}-#{opts[:digest]}.wav"
  end
end

task :noop
task default: :noop

SILENT_10 = File.expand_path("./misc/silent-1.0s.wav")
CONFIG_DIR = File.dirname(File.expand_path(ENV["conf"]))
CONFIG = YAML.load_file(ENV["conf"])
ROOT = "out/#{CONFIG["project"]}"
DIR = {
  raw: "#{ROOT}/raw",
  concat: "#{ROOT}/concat",
  compile: "#{ROOT}/compile",
  mp3: "#{ROOT}/mp3",
  mix: "#{ROOT}/mix",
}

def build_filelist(source_file, rule_name)
  extname = File.extname(source_file)
  basename = File.basename(source_file, extname)

  filename_opts = {rule_name: rule_name, basename: basename}
  filelist = {
    source: source_file,
    mix: file_for(:mix, filename_opts),
    mp3: file_for(:mp3, filename_opts),
    compile: file_for(:compile, filename_opts),
    concat: [],
    raw: [],
    say_spec_by_raw: {},
  }

  required_fields = CONFIG['concat'][rule_name].uniq

  File.readlines(source_file).each_with_index do |line, index|
    line.chomp!

    lineno = "%04d" % (index + 1)
    prefix = "#{basename}-#{lineno}"
    filelist[:concat] << file_for(:concat, filename_opts.merge!(lineno: lineno))

    raw_by_field = {}
    line.split(/\t/).each_with_index do |content, index|
      field = CONFIG['fields'].keys[index]
      next unless required_fields.include?(field)

      voice = CONFIG['fields'][field]
      next unless voice

      filter = CONFIG['filter'][field]
      content = Filter.send(filter, content) if filter

      digest = Digest::SHA256.hexdigest(content)
      raw_file = file_for :raw, filename_opts.merge({field: field, digest: digest})
      filelist[:say_spec_by_raw][raw_file] = [voice, content]
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

    desc "itune"
    task :itune => filelist[:mix] do
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
      artist = CONFIG['album'][rule_name]['artist']
      options << "-a #{artist}" if artist
      title = CONFIG['album'][rule_name]['title']
      options << "-A #{title}" if title
      jacket = CONFIG['album'][rule_name]['jacket']
      options << "--add-image #{File.join(CONFIG_DIR, jacket)}:FRONT_COVER" if jacket

      sh "eyeD3 #{options.join(' ')} --add-lyrics #{filelist[:source]} #{t.source}"
    end

    # mix
    #----------------
    file filelist[:mix] => filelist[:mp3] do |t|
      mkdir_p DIR[:mix], verbose: false

      mix_muic = ENV['mix']
      if mix_muic
        duration=`soxi #{t.source} | grep Duration | awk '{ print $3 }'`.chomp
        sh "sox -m #{t.source} #{mix_muic} #{t.name} trim 00:00.00 #{duration}"
      else
        warn "you need to pass 'music' env var"
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
      sh "sox #{t.sources.join(" ")} #{t.name}"
    end

    desc "compile"
    task compile: filelist[:compile]

    # concat
    #----------------
    filelist[:concat].each_with_index do |concat_file, index|
      raw_file_by_field = filelist[:raw][index]

      file concat_file => raw_file_by_field.values do |t|
        mkdir_p DIR[:concat], verbose: false
        files = CONFIG['concat'][rule_name].map do |field|
          field = field.to_s
          field === "1.0" ? SILENT_10 : raw_file_by_field[field]
        end
        sh "sox #{files.join(" ")} #{t.name}"
      end
    end

    desc "concat"
    task concat: filelist[:concat]

    # raw
    #----------------
    desc "raw"
    task raw: filelist[:say_spec_by_raw].keys

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
  raw: [],
  say_spec_by_raw: {},
}

CONFIG['concat'].keys.each do |rule_name|
  filelist = build_filelist(ENV['src'], rule_name)
  all_files[:mp3] << filelist[:mp3]
  all_files[:mix] << filelist[:mix]
  all_files[:compile] << filelist[:compile]
  all_files[:concat].concat(filelist[:concat])
  all_files[:raw].concat(filelist[:say_spec_by_raw].keys)
  all_files[:say_spec_by_raw].merge!(filelist[:say_spec_by_raw])

  define_task(filelist, rule_name)
end

all_files[:raw].uniq!

# raw
#----------------
all_files[:say_spec_by_raw].each do |raw_file, say_spec|
  file raw_file do
    mkdir_p DIR[:raw], verbose: false
    voice, content = say_spec
    audio = say(content, name: voice).audio_content
    File.write(raw_file, audio, mode: "wb")
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
  end
end
