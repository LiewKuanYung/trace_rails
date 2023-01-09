require "singleton"
require_relative "tracer_logger"

class TracerCollector 
  include Singleton
  include TracerLogger::ColorLog

  attr_accessor :uri, :calls, :calls_overview, :lines, :lines_overview, :returns

  HOME_PATH        = Dir.home  + "/"
  CURRENT_PATH     = __dir__
  ROOT_PATH        = File.expand_path('../..', __dir__) + "/"
  RAILS_PATH       = Gem::Specification.find_by_name("rails").gem_dir
  GEM_PATH         = File.expand_path('../..', RAILS_PATH) + "/" # Should be valid for rbenv and rvm
  APP_PATH         = ROOT_PATH + "app/"
  LIB_PATH         = ROOT_PATH + "lib/"
  TRACER_PATH      = CURRENT_PATH

  ROOT_PATH_LENGTH = ROOT_PATH.length
  HOME_PATH_LENGTH = HOME_PATH.length
  GEM_PATH_LENGTH  = GEM_PATH.length

  CALLS_LIMIT      = 5
  LINES_LIMIT      = 3
  CALLER_LIMIT     = 3

  def initialize
    @uri = "uri"
    @uri_count = 0
    @uri_key = "0: uri"

    @calls = {}
    @calls_overview = {}
    @lines = {}
    @lines_overview = {}
    @returns = {}
  end

  def self.method_missing(name, *args, &block)
    instance.send(name, *args, &block)
  end

  #
  #
  # Collect data
  #
  #

  def collect_lines(data)
    @lines[@uri_key] ||= {uri: @uri, data:[]}
    @lines[@uri_key][:data].append(data)
  end

  def collect_calls(data)
    @calls[@uri_key] ||= {uri: @uri, data:[]}
    @calls[@uri_key][:data].append(data)
  end

  def collect_returns(data)
    @returns[@uri_key] ||= {uri: @uri, data:[]}
    @returns[@uri_key][:data].append(data)
  end

  def collect_and_group_calls(tp)
    klass = extract_klass_name(tp)
    items = @calls_overview.dup
    items[klass] ||= {}
    items[klass]["path"] = tp.path[ROOT_PATH_LENGTH..-1]
    items[klass][tp.method_id] ||= 0
    items[klass][tp.method_id] += 1
    @calls_overview = items
  end

  def extract_klass_name(tp)
    defined_klass = tp.defined_class.to_s
    self_klass = tp.self.class.name 

    unless self_klass
      # if caller.start_with? "app/views"
      #   return "#{defined_klass} caller from views"
      # elsif caller.start_with? "app/helpers"
      #   return "#{defined_klass} caller from helper"
      # else
      #   # Most likely from ActionView
      #   return "#{defined_klass} caller unknown"
      # end

      return "#{defined_klass}"
    end
    
    if self_klass == defined_klass
      return defined_klass
    elsif self_klass == "Module" or self_klass == "Class"
      return tp.self.name
    else
      return "#{self_klass} < #{defined_klass}"
    end
  end

  def extract_locals(tp)
    local_names = tp.binding.local_variables.reject { |v|
      v.to_s[0] == '_'
    }
    local_names.map { |n|
      value = tp.binding.local_variable_get(n)
      [n, value.is_a?(TracePoint) ? :trace_point : value]
    }.to_h
  end

  #
  #
  # Print or download data
  #
  #

  def print_calls_overview_report(detail: false)
    totals = {}
    longest_name_size = 0

    @calls_overview.each do |klass, methods|
      if klass && klass.length > longest_name_size
        longest_name_size = klass.length
      end

      totals[klass] ||= 0
      log_klass_and_path(klass, methods['path'])
      # Only one key-value pair is path, the rest are calls count. 
      # Remove it to avoid sort_by comparing string with int
      methods.delete("path")

      # Print calls count, and sum up the totals of all methods count of a klass
      methods = methods.sort_by {|k, v| v}.reverse
      methods.each do |method, count|
        totals[klass] += count
        printf "\t%-30s %s\n", method, count if detail
      end
      puts "\n" if detail
    end
    
    puts "\n--------------------"
    puts "Total methods called by each class:\n"
    totals = totals.sort_by {|k, v| v}.reverse
    
    total_calls = 0
    totals.each do |klass, total|
      total_calls += total
      printf "\t%-#{longest_name_size}s %s\n", klass, total if detail
    end
    puts "\n\ntotal class or module: #{@calls_overview.keys.count}"
    puts "total method calls: #{total_calls}\n\n"
  end

  def download_lines
    opts = { array_nl: "\n"}
    File.open("#{TRACER_PATH}/data/lines.json","w") do |f|
      f.write(JSON.generate(@lines, opts))
    end
  end

  def download_calls
    File.open("#{TRACER_PATH}/data/calls.json","w") do |f|
      f.write(JSON.pretty_generate(@calls))
    end
  end

  def download_returns
    File.open("#{TRACER_PATH}/data/returns.json","w") do |f|
      f.write(JSON.pretty_generate(@returns))
    end
  end

  #
  #
  # Other
  #
  #

  def clear
    @uri_count += 1

    clear_calls
    @calls_overview.clear

    clear_lines
    @lines_overview.clear

    @returns.clear
  end

  def clear_calls
    k = @calls.keys
    if k.count > CALLS_LIMIT
      @calls.delete(k[0])
    end
  end

  def clear_lines
    k = @lines.keys
    if k.count > LINES_LIMIT
      @lines.delete(k[0])
    end
  end

  def set_call_key(request_path)
    @uri_key = "#{@uri_count}: #{request_path}"
  end
end
