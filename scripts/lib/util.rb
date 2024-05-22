module Utils

  def colorize(string)
    unless ENV["TERM_PROGRAM"] =~ /(iTerm.app|Apple_Terminal)/
      return string
    end
    colors = {
      'red' => "\033[1;31m",
      'green' => "\033[32m",
      'yellow' => "\033[33m",
      'blue' => "\033[1;34m",
      'magenta' => "\033[1;35m",
      'cyan' => "\033[1;36m",
      'white' => "\033[1;37m",
      'r' => "\033[0;39m"
    }

    string.sub!(/^(\[[\d:]+\]: )?([^a-z0-9 ]+)?(.*)/i, %Q{%%green%%\\1%%yellow%%\\2%%white%%\\3%%r%%})
    string.gsub!(/([a-z]+ing|[a-z]+[it]ed)\b/i,%Q{%%magenta%%\\1%%r%%})
    string.gsub!(/\b((?:keyword )?index|sidebar|(?:home )?page|images?|css|changelog|search|js)/i,%Q{%%cyan%%\\1%%r%%})
    string.gsub!(/(error:?)/i,%Q{%%red%%\\1%%r%%})
    string.gsub!(/%%(\w+?)%%/) {|m|
      colors[$1]
    }
  end
  module_function :colorize

  def load_config (config_file)
    File.open(config_file) { |yf| YAML::load(yf) }
  end
  module_function :load_config

  def dump_config (config)
    File.open(config_file, 'w') { |yf| YAML::dump(config, yf) }
  end
  module_function :dump_config

  def load_template (template)
    return IO.read(template)
  end
  module_function :load_template

  def find_headers(lines)
    in_headers = false
    lines.each_with_index {|line, i|
      if line =~ /^\S[^\:]+\:( .*?)?$/
        in_headers = true
      elsif in_headers === true
        return i
      else
        return false
      end
    }
  end
  module_function :find_headers

  def remove_todos(text)
    text.gsub!(/(^(TODO|FIX(ME)?):.*?$|\s*\((TODO|FIX(ME)?):.*?\))/,'')
    out = text.split(/(<!-- *NOTES *-->|__(NOTES|END|TODO)__)/i)[0]
    out
  end
  module_function :remove_todos

  def update_status(update,options = {})

    last = options[:last] || false

    unless ENV['TERM']
      ENV['TERM'] = "xterm"
    end

    # Get the terminal width using *nix `tput` command running every time to try to handle resizing windows
    begin
      cols = %x{tput cols}.strip.to_i - 17
    rescue
      cols = 68
    end
    # trim output so it doesn't break to a second line
    update = update.slice(0,cols) if update.length > cols
    # if it's not the last output, use a carriage return instead of a newline as terminator
    terminator = last ? "\n" : "\r"
    # add date
    t = Time.now.strftime('%H:%M:%S')
    update = colorize(%Q{[#{t}]: #{update}})
    # Print to STDERR
    DEFAULT_SETTINGS[:status].printf("\033[K%s%s",update,terminator)

    DEFAULT_SETTINGS[:status].flush if last
  end
  module_function :update_status

end

