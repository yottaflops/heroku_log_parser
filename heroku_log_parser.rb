# Run via terminal: ruby heroku_log_parser.rb [LOG_PATH]

class HerokuLogParser
  def initialize(path)
    raise FileNotFoundError, "There is no file with that name in the specified directory" unless File.exists?(path)

    @log = File.open(path)
    @dynos = []
    @response_times = []
    @endpoints = { pending_msgs: 0, messages: 0, get_f_progress: 0, get_f_score: 0, user_post: 0, user_get: 0 }
    @total_requests = 0
  end

  def parseLog
    @log.each_line do |line|
      cache_dyno(line)
      cache_response_time(line)
      tally_request(line)
      @total_requests += 1
    end

    pretty_print_outputs
  end

 private

  def cache_dyno(text)
    dyno_param = /dyno\S*/.match(text).to_s
    dyno = dyno_param.match(/\d+/)[0].to_i

    @dynos.push(dyno)
  end

  def cache_response_time(text)
    response_param = /connect\S*/.match(text).to_s
    response_time = response_param.match(/\d+/)[0].to_i

    @response_times.push(response_time)
  end

  def tally_request(text)
    method_param = /method\S*/.match(text).to_s
    request_method = method_param.match(/[^method=].*/)[0].to_s

    return @endpoints[:user_post] += 1 if request_method == "POST"

    path_param = /path\S*/.match(text).to_s
    request_path = path_param.match(/[^path=].*/)[0].to_s

    if request_path =~ /count_pending_messages/
      @endpoints[:pending_msgs] += 1
    elsif request_path =~ /get_messages/
      @endpoints[:messages] += 1
    elsif request_path =~ /get_friends_progress/
      @endpoints[:get_f_progress] += 1
    elsif request_path =~ /get_friends_score/
      @endpoints[:get_f_score] += 1
    else
      @endpoints[:user_get] += 1
    end
  end

  def output_response_times
    puts "The mean response time was #{@response_times.mean} ms."
    puts "The median response time was #{@response_times.median} ms."
    puts "The mode of the response times was #{@response_times.mode} ms."
  end

  def output_request_metrics
    puts "Out of #{@total_requests} requests:"
    puts ""
    puts "There were #{@endpoints[:pending_msgs]} GET requests to '/api/users/{user_id}/count_pending_messages'."
    puts "There were #{@endpoints[:messages]} GET requests to '/api/users/{user_id}/get_messages'."
    puts "There were #{@endpoints[:get_f_progress]} GET requests to '/api/users/{user_id}/get_friends_progress'."
    puts "There were #{@endpoints[:get_f_score]} GET requests to '/api/users/{user_id}/get_friends_score'."
    puts "There were #{@endpoints[:user_get]} GET requests to '/api/users/{user_id}'."
    puts "There were #{@endpoints[:user_post]} POST requests to '/api/users/{user_id}'."
  end

  def output_dyno_metrics
    puts "The most active dyno was dyno ##{@dynos.mode}."
    puts "The least active dyno was dyno ##{@dynos.mode(true)}."
  end

  def pretty_print_outputs
    puts""
    puts "\e[36mREQUEST METRICS"
    puts "===============\033[0m\n"
    output_request_metrics
    puts""
    puts "\e[36mRESPONSE TIME METRICS"
    puts "=====================\033[0m\n"
    output_response_times
    puts""
    puts "\e[36mDYNO USAGE METRICS"
    puts "==================\033[0m\n"
    output_dyno_metrics
    puts""
  end
end

class Array
  #DISCLAIMER: I found some of the array class extension logic online and altered it to suit this project
  def median
    sorted = self.sort
    mid = (sorted.length - 1) / 2
    (sorted[mid.floor] + sorted[mid.ceil]) / 2
  end

  def mean
    sum = inject(0.0) { |x, y| x + y }
    sum / size
  end

  def mode(get_inverse=false)
    enum = get_inverse ? :min : :max
    group_by { |i| i }.send(enum){ |x, y| x[1].length <=> y[1].length }[0]
  end
end

class FileNotFoundError < StandardError
end

parser = HerokuLogParser.new(*ARGV)
parser.parseLog
