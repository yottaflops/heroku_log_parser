# Run via terminal: ruby heroku_log_parser.rb [LOG_PATH]

require 'pry'
class HerokuLogParser
  def initialize(path)
    raise FileNotFoundError, "There is no file with that name in the specified directory" unless File.exists?(path)

    @log = File.open(path)
    @endpoints = {
      pending_msgs: { requests: 0, dynos: [], response_times: [] },
      messages: { requests: 0, dynos: [], response_times: [] },
      get_f_progress: { requests: 0, dynos: [], response_times: [] },
      get_f_score: { requests: 0, dynos: [], response_times: [] },
      user_post: { requests: 0, dynos: [], response_times: [] },
      user_get: { requests: 0, dynos: [], response_times: [] },
      other: { requests: 0, dynos: [], response_times: [] }
    }
    @total_requests = 0
  end

  def parseLog
    @log.each_line do |line|
      request_key = get_request_key(line)
      tally_request(request_key)
      cache_dyno(line, request_key)
      cache_response_time(line, request_key)
      @total_requests += 1
    end
    puts @endpoints
    pretty_print_outputs
  end

 private

  def get_request_key(text)
    method_param = /method\S*/.match(text).to_s
    request_method = method_param.match(/[^method=].*/)[0].to_s
    path_param = /path\S*/.match(text).to_s
    request_path = path_param.match(/[^path=].*/)[0].to_s

    if request_method == "POST"
      if request_path =~ /users/
        return :user_post
      else
        return :other
      end

    elsif request_method == "GET"
      if request_path =~ /count_pending_messages/
        :pending_msgs
      elsif request_path =~ /get_messages/
        :messages
      elsif request_path =~ /get_friends_progress/
        :get_f_progress
      elsif request_path =~ /get_friends_score/
        :get_f_score
      elsif request_path =~ /users/
        :user_get
      else
        :other
      end
    else
      return :other
    end
  end

  def cache_dyno(text, request_key)
    dyno_param = /dyno\S*/.match(text).to_s
    dyno = dyno_param.match(/\d+/)[0].to_i

    @endpoints[request_key][:dynos].push(dyno)
  end

  def cache_response_time(text, request_key)
    connect_param = /connect\S*/.match(text).to_s
    connect_time = connect_param.match(/\d+/)[0].to_i

    service_param = /service=\S*/.match(text).to_s
    service_time = service_param.match(/\d+/)[0].to_i

    response_time = connect_time + service_time

    @endpoints[request_key][:response_times].push(response_time)
  end

  def tally_request(request_key)
    @endpoints[request_key][:requests] += 1
  end

  def output_request_metrics(request_key)
    output_request_totals(request_key)
    output_response_times(request_key)
    output_dyno_metrics(request_key)
  end

  def output_request_totals(request_key)
    puts "Requests made: #{@endpoints[request_key][:requests]}"
  end

  def output_response_times(request_key)
    puts "Mean response time: #{@endpoints[request_key][:response_times].mean} ms"
    puts "Median response time: #{@endpoints[request_key][:response_times].median} ms"
    puts "Mode of response times: #{@endpoints[request_key][:response_times].mode} ms"
  end

  def output_dyno_metrics(request_key)
    puts "Most active dyno: #{@endpoints[request_key][:dynos].mode}"
    puts "Least active dyno: #{@endpoints[request_key][:dynos].mode(true)}"
  end

  def pretty_print_outputs
    puts""
    puts "Out of #{@total_requests} requests:"
    puts ""
    puts "\e[36mGET requests to '/api/users/{user_id}/count_pending_messages'"
    puts "=============================================================\033[0m\n"
    output_request_metrics(:pending_msgs)
    puts ""
    puts "\e[36mGET requests to '/api/users/{user_id}/get_messages'"
    puts "===================================================\033[0m\n"
    output_request_metrics(:messages)
    puts ""
    puts "\e[36mGET requests to '/api/users/{user_id}/get_friends_progress'"
    puts "===========================================================\033[0m\n"
    output_request_metrics(:get_f_progress)
    puts ""
    puts "\e[36mGET requests to '/api/users/{user_id}/get_friends_score'"
    puts "========================================================\033[0m\n"
    output_request_metrics(:get_f_score)
    puts ""
    puts "\e[36mGET requests to '/api/users/{user_id}'"
    puts "======================================\033[0m\n"
    output_request_metrics(:user_get)
    puts ""
    puts "\e[36mPOST requests to '/api/users/{user_id}'"
    puts "=======================================\033[0m\n"
    output_request_metrics(:user_post)
    puts ""
    puts "\e[36mPOST requests to other urls"
    puts "=======================================\033[0m\n"
    output_request_metrics(:other)
    puts ""
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
