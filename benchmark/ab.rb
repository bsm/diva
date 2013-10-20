#!/usr/bin/env ruby

require 'bundler/setup'
require 'resty_test'

RestyTest.config.root = File.expand_path("../resty", __FILE__)
RestyTest.config.source = "http://openresty.org/download/ngx_openresty-1.4.2.8.tar.gz"
RestyTest.start!

RELEVANT = /Document Length|Document Path|Failed requests|Time taken|Total transferred|Requests per second/

def ab(path)
  args = ARGV.empty? ? ["-n", 100000, "-c", 5] : ARGV

  print "--> Benchmarking /#{path}\n\n"
  `ab -q #{args.join(" ")} "http://localhost:8080/#{path}"`.lines.each do |l|
    puts l if l =~ RELEVANT
  end
  puts
end

puts

# Forwards
ab("case_a")
ab("case_b")
ab("plain")

# Backwards
ab("plain")
ab("case_b")
ab("case_a")

RestyTest.stop!
