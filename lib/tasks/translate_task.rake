require 'net/http'
require 'rexml/document'
require 'bing_translator'

desc "Translate your YAML files using Bing."
task :bing_translate => :environment do
  @from_locale = ENV["from"]
  raise "need to specify from=<locale>" unless @from_locale

  @to_locale = ENV["to"]
  raise "need to specify to=<locale>" unless @to_locale

  @client_id = ENV["client_id"]
  raise "need to specify client_id=<Your Bing API Client id>" unless @client_id

  @client_secret = ENV["client_secret"]
  raise "need to specify client_secret=<Your Bing API Client secret>" unless @client_secret


  source_size = source_files.size

  puts "Translating #{source_size} files..."

  source_files.each_with_index do |source_file, index|
    puts source_file
    translate_file(source_file)
    puts "#{(index+1).to_f / source_size * 100} %"
  end

  puts "Done!"
end

def translate_file(source_path)
  source_yaml = YAML::load(File.open(source_path))
  source = source_yaml ? source_yaml[@from_locale] || {} : {}
  translated = translate_hash(source)
  save_to_file(translated, destination_path(source_path))
end

# ../locales/views/health_library/health_library.en.yml
# => ../locales/views/health_library/health_library.es.yml
def destination_path(source_path)
  dest_basename = File.basename(source_path, ".#{@from_locale}.yml")
  dirname = File.dirname(source_path)
  File.join(dirname, "#{dest_basename}.#{@to_locale}.yml")
end

def save_to_file(translated, dest_path)
  out = { @to_locale => translated }
  File.open(dest_path, 'w') {|f| YAML.dump(out, f) }
end

def translate_hash(yaml)
  dest = yaml.dup

  yaml.keys.each do |key|
    source = yaml[key]

    if source.is_a?(Symbol)
      translated = source
    elsif source.is_a?(String)
      translated = translate_string(source)
    elsif source.is_a?(Hash)
      translated = translate_hash(source)
    elsif source.is_a?(Array)
      translated = translate_array(source)
    else
      translated = ""
    end

    dest[key] = translated
  end

  dest
end

def translate_array(array)
  out = []
  array.each do |source|
    if source.is_a?(Symbol)
      out << source
    else
      out << translate_string(source)
    end
  end
  out
end

def translate_string(source)
  return "" unless source

  dest = translator.translate(source, :from => @from_locale, :to => @to_locale)

  puts "#{source} => #{dest}"

  dest
end

def translator
  @translator ||= BingTranslator.new(@client_id, @client_secret)
end


def source_files
  return @source_files if @source_files
  given = ENV["path"]
  @source_files = if given
    if File.directory?(given)
      puts "Using given path '#{given}'"
      Dir[File.join(given, "**", "*.#{@from_locale}.yml")]
    else
      puts "Using given file: '#{given}'"
      [given]
    end
  else
    puts "Path not given. Selecting all files in config/locales/"
    Dir[File.join(Rails.root, "config/locales", "**", "*.#{@from_locale}.yml")]
  end
end