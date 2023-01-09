require_relative "tracer"
require_relative "tracer_logger"

class TracerMiddleware
  include TracerLogger::ColorLog

  ROOT_PATH        = TracerCollector::ROOT_PATH
  GEM_PATH         = TracerCollector::GEM_PATH
  APP_PATH         = TracerCollector::APP_PATH
  LIB_PATH         = TracerCollector::LIB_PATH
  TRACER_PATH      = TracerCollector::TRACER_PATH

  ROOT_PATH_LENGTH = ROOT_PATH.length
  GEM_PATH_LENGTH  = GEM_PATH.length

  #
  #
  # Middleware features
  #
  #

  def initialize(app)
    @app = app
    @opts = {
      call:          true, # Trace :call event
      call_details:  true, # Print details call event in terminal
      download_call: true, # Download call event into data/calls.json

      line:          true, # Trace :line event
      download_line: true, # Download line event into data/lines.json

      # Not available at the moment
      # return:          false,
      # download_return: false,
      # raise:          false,
      # download_raise: false,
      # line_context:  false, # Collect local variables data

      filters: {
        include_path_start_with: [APP_PATH, LIB_PATH],
        exclude_path_start_with: [TRACER_PATH]
      }
    }
    version = TRACER_PATH[-3..-2]
    tracing = @opts.keys.select{ |k| @opts[k] == true }.join(", ")
    log_color("TracerMiddleware#initialize #{version}", :blue, tracing)
  end

  def call(env)
    log_color("TracerMiddleware#call (START OF REQUEST)", :green)
    dup._call(env)
  end

  def _call(env)
    @req = {
      method: env["REQUEST_METHOD"], 
      path:   env["REQUEST_PATH"], 
      uri:    env["REQUEST_URI"] # uri will include query or param
    }

    # Initialize tracer here
    initialize_tracer
    @tracers.map(&:enable)

    # App handle request, and return response
    # @start = Time.now
    @status, @headers, @response = @app.call(env)
    # @end = Time.now
    # puts "Response Time: #{@start} - #{@end}"

    [@status, @headers, self]
  end

  def each(&block)
    block.call("")
    @response.each(&block)
    log_color("TracerMiddleware#each (END OF RESPONSE)", :red)

    @tracers.map(&:disable)
    print_tracers_data
    download_tracers_data
    return
  end

  #
  #
  # Tracer features
  #
  #

  def initialize_tracer
    # Clear everything before starting tracer
    @tracers = []
    TracerCollector.clear
    TracerCollector.uri = @req[:uri]
    TracerCollector.set_call_key(@req[:path])

    trace_call_event   if @opts[:call]
    trace_line_event   if @opts[:line]
    trace_return_event if @opts[:return]
  end

  def trace_call_event
    @tracers << TracePoint.new(:call) do |tp|
      if filter_path(tp.path)
        TracerCollector.collect_and_group_calls(tp)
        TracerCollector.collect_calls({
          path: tp.path[ROOT_PATH_LENGTH..-1],
          line: tp.lineno,
          method: tp.method_id,
          caller: filter_callers(tp.binding.send(:caller))
        })
      end
    end
  end

  def trace_line_event
    @tracers << TracePoint.new(:line) do |tp|
      if filter_path(tp.path)
        TracerCollector.collect_lines({
          path: tp.path[ROOT_PATH_LENGTH..-1],
          line: tp.lineno, 
          method: tp.method_id
        })
      end
    end
  end

  def filter_path(path)
    ( 
      path.start_with?(*@opts[:filters][:include_path_start_with]) and 
      not path.start_with?(*@opts[:filters][:exclude_path_start_with]) 
    )
  end

  def filter_callers(callers)
    # Drop first path because it represents the method_id itself, then filter path string
    n = TracerCollector::CALLER_LIMIT
    callers.drop(1).first(n).map {|path|
      path.start_with?(ROOT_PATH) ? path[ROOT_PATH_LENGTH..-1] : path[GEM_PATH_LENGTH..-1]
    }
  end

  # TODO
  # trace_raise_event
  # trace_return_event

  #
  #
  # Logging and download features
  #
  #

  def print_tracers_data
    TracerCollector.print_calls_overview_report(detail: @opts[:call_details]) if @opts[:call]
  end

  def download_tracers_data
    TracerCollector.download_calls   if @opts[:download_call]   and @opts[:call]
    TracerCollector.download_lines   if @opts[:download_line]   and @opts[:line]
    TracerCollector.download_returns if @opts[:download_return] and @opts[:return]
  end
end
