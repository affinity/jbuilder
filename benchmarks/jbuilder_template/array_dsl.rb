# frozen_string_literal: true

require 'benchmark/ips'
require 'benchmark/memory'
require_relative '../../lib/jbuilder'
require_relative '../../lib/jbuilder/jbuilder_template'

Post = Struct.new(:id, :body)
json = JbuilderTemplate.new nil

Benchmark.ips do |x|
  x.report('before') do |n|
    n.times { json.array! }
  end
  x.report('after') do |n|
    n.times { json.array! }
  end

  x.hold! 'temp_array_ips'
  x.compare!
end

json = JbuilderTemplate.new nil

Benchmark.memory do |x|
  x.report('before') { json.array! }
  x.report('after') { json.array! }

  x.hold! 'temp_array_memory'
  x.compare!
end
