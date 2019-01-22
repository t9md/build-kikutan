require 'digest/sha2'
require "yaml"
require 'pp'

require "google/cloud/text_to_speech"

# Quilck Reference for Rakefile:
# https://gist.github.com/noonat/1649543

def validate_env_and_file(key)
  if ENV[key] and File.exist?(ENV[key])
    return
  end
  warn <<-EOS

  You need to pass '#{key}' as env var like below and that file must be exist.

  $ rake conf=src/svl/config.yml src=src/svl/svl-02.txt -T"

  EOS
  exit 1
end

validate_env_and_file('conf')
validate_env_and_file('src')

CONF_DIR = File.dirname(File.expand_path(ENV["conf"]))
DEFAULT_CONFIG = {
  'dir_out' => './out',
  'dir_raw' => './raw',
  'compile' => {},
  'filter' => {},
  'mix' => {},
}
CONF = DEFAULT_CONFIG.merge(YAML.load_file(ENV["conf"]))

OUT = File.absolute_path(CONF['dir_out'], CONF_DIR)
DIR = {
  raw: File.absolute_path(CONF['dir_raw'], CONF_DIR),
  silent: "#{OUT}/silent",
  concat: "#{OUT}/concat",
  compile: "#{OUT}/compile",
  mp3: "#{OUT}/mp3",
}

def load_filter
  Dir.glob("filter/*.rb") do |filter|
    load(filter)
  end
end
unless CONF['filter'].keys.empty?
  load_filter
end

def say(voice, content)
  options = { name: voice, language_code: voice[0..4] }
  synthesis_input = { text: content }
  audio_config = { audio_encoding: "LINEAR16" }
  client = Google::Cloud::TextToSpeech.new
  result = client.synthesize_speech synthesis_input, options, audio_config
  result.audio_content
end

task :example do
  warn <<-EOS
  ## Show task list
  $ rake conf=src/svl/config.yml src=src/svl/svl-02.txt -T

  ## Compile with "en_ja" rule. Generate "out/svl-en_ja--svl-01.wav".
  $ rake conf=src/svl/config.yml src=src/svl/svl-02.txt en_ja:compile

  See README.md for more detail.
  EOS
end

def play(file)
  tempo = ENV['tempo']
  cmd = "play -q #{file}"
  cmd += " tempo #{tempo}" if tempo
  sh cmd
end

task default: :example

# out/svl/mp3/svl-en_ja_en--svl-01.mp3
# out/svl/compile/svl-en_ja_en--svl-01.wav
# out/svl/concat/svl-en_ja_en--svl-01--0001.wav
# out/svl/concat/svl-en_ja_en--svl-01--0002.wav
# out/svl/raw/ca978112...ee48bb.wav
# out/svl/raw/09e62852...3e05ef.wav
# out/svl/raw/b0ad6bc1...b11365.wav
# out/svl/raw/f47a89d2...a2ceb7.wav
def build_filelist(source_file, rule_name)
  basename = source_file.pathmap('%n') # base name without ext
  prefix = "#{CONF["project"]}-#{rule_name}--#{basename}"
  src_lines = File.readlines(source_file)

  filelist = {
    source: source_file,
    mp3: "#{DIR[:mp3]}/#{prefix}.mp3",
    compile: "#{DIR[:compile]}/#{prefix}.wav",
    concat: 1.upto(src_lines.size).map { |n| "#{DIR[:concat]}/#{prefix}--#{'%04d' % n}.wav" },
    raw: [],
    say_args_by_raw: {},
    silent_by_duration: {}
  }

  required_fields = CONF['concat'][rule_name].uniq
  required_fields.select { |d| d.is_a?(Numeric) }.each do |duration|
    filelist[:silent_by_duration][duration] = "#{DIR[:silent]}/#{duration}.wav"
  end

  field_voice = CONF['field'].to_a
  src_lines.each_with_index do |line, index|
    line.chomp!

    raw_by_field = {}
    line.split(/\t/).each_with_index do |content, index|
      field, voice = field_voice[index]
      next unless voice
      filter = CONF['filter'][field]
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
      artist = CONF['album'][rule_name]['artist']
      title = CONF['album'][rule_name]['title']
      music_dir = File.join(ENV['HOME'], "Music/iTunes/iTunes Music/Music")
      if artist and title
        album_dir = File.join(music_dir, artist, title)
        if File.directory?(album_dir)
          target_dir = album_dir
        else
          target_dir = File.join(music_dir, "Automatically Add to iTunes")
        end
        cp filelist[:mp3], target_dir, verbose: true
      end
    end

    # album
    #----------------
    desc "album"
    task "album": filelist[:mp3] do |t|
      options = []
      artist = CONF['album'][rule_name]['artist']
      options << "-a #{artist}" if artist
      title = CONF['album'][rule_name]['title']
      options << "-A #{title}" if title
      jacket = CONF['album'][rule_name]['jacket']
      options << "--add-image #{File.absolute_path(jacket, CONF_DIR)}:FRONT_COVER" if jacket
      lyrics = filelist[:source]
      sh "eyeD3 -Q #{options.join(' ')} --add-lyrics #{lyrics} #{t.source}"
    end

    namespace :album do
      desc "play"
      task play: "mp3:play"
    end

    # mp3
    #----------------
    file filelist[:mp3] => filelist[:compile] do |t|
      mkdir_p DIR[:mp3], verbose: false
      mp3 = t.name
      tmp_mp3 = t.name + "tmp.mp3" # ".mp3" extension is significant for ffmpeg to know the type of music, keep it.

      sh "ffmpeg -loglevel quiet -i #{t.source} -vn -ac 2 -ar 44100 -ab 256k -acodec libmp3lame -f mp3 #{mp3}"

      mix = ENV['mix']
      if not mix and CONF['mix'][rule_name]
        mix = File.absolute_path(CONF['mix'][rule_name], CONF_DIR)
      end

      if mix
        duration=`soxi #{mp3} | grep Duration | awk '{ print $3 }'`.chomp
        sh "sox #{mp3} -m #{mix} #{tmp_mp3} trim 00:00.00 #{duration} fade 0 -0 6"
        mv tmp_mp3, mp3, verbose: true
      end
    end

    desc "mp3"
    task mp3: filelist[:mp3]

    namespace :mp3 do
      desc "play"
      task play: filelist[:mp3] do |t|
        play t.source
      end
    end

    # compile
    #----------------
    file filelist[:compile] => filelist[:concat] do |t|
      mkdir_p DIR[:compile], verbose: false
      files = filelist[:concat]
      if CONF['compile'][rule_name] === "shuffle"
        files = files.shuffle
      end
      sh "sox #{files.join(" ")} #{t.name} pad 0 7" # pad with 7s silence at end.
    end

    desc "compile"
    task compile: filelist[:compile]

    namespace :compile do
      desc "play"
      task play: filelist[:compile] do |t|
        play t.source
      end
    end

    # concat
    #----------------
    filelist[:concat].each_with_index do |concat_file, index|
      raw_file_by_field = filelist[:raw][index]

      depends = raw_file_by_field.values + filelist[:silent_by_duration].values()
      file concat_file => depends do |t|
        mkdir_p DIR[:concat], verbose: false
        files = CONF['concat'][rule_name].map { |field|
          raw_file_by_field[field] || filelist[:silent_by_duration][field]
        }
        sh "sox #{files.join(" ")} #{t.name}"
      end
    end

    desc "concat"
    task concat: filelist[:concat]

    namespace :concat do
      desc "play"
      task :play, [:line] => filelist[:concat] do |t, args|
        line = args[:line].to_i
        play(t.sources[line - 1]) if line > 0
      end
    end

    # Raw
    #----------------
    raw_files = filelist[:say_args_by_raw].keys
    desc "raw"
    task raw: raw_files

    namespace :raw do
      desc "play"
      task :play, [:line, :field] => raw_files do |t, args|
        line = args[:line].to_i
        play filelist[:raw][line - 1][args[:field]] if line > 0
      end
    end
  end
end

say_args_by_raw = {}

CONF['concat'].keys.each do |rule_name|
  filelist = build_filelist(ENV['src'], rule_name)
  say_args_by_raw.merge!(filelist[:say_args_by_raw])
  define_task(filelist, rule_name)
end

# silent
#----------------
rule %r{#{OUT}/silent/.*.wav} do |t|
  mkdir_p DIR[:silent], verbose: false
  # Silent flename is just duration.  ex) out/svl/silent/1.0.wav
  duration = t.name.pathmap('%n')
  sh "sox -n #{t.name} trim 0 #{duration} rate 24000"
end

# raw
#----------------
say_args_by_raw.each do |raw_file, say_args|
  file raw_file do
    mkdir_p DIR[:raw], verbose: false
    File.write(raw_file, say(*say_args), mode: "wb")
    puts "GOT: #{say_args}"
  end
end

desc "clean: Clean all files except 'raw' directory."
task :clean do
  rm_rf DIR[:mp3]
  rm_rf DIR[:compile]
  rm_rf DIR[:concat]
  rm_rf DIR[:silent]
end
