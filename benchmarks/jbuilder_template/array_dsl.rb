# frozen_string_literal: true

require 'benchmark/ips'
require 'benchmark/memory'
require_relative '../../lib/jbuilder'
require_relative '../../lib/jbuilder/jbuilder_template'

Post = Struct.new(:id, :body)
json = JbuilderTemplate.new nil
posts = 3.times.map { Post.new(it, "Post ##{it}") }

Benchmark.ips do |x|
  x.report('before') do
    json.array!(nil)
  end
  x.report('after') do
    json.array!(nil)
  end

  x.hold! 'temp_array_ips'
  x.compare!
end

json = JbuilderTemplate.new nil

Benchmark.memory do |x|
  x.report('before') { json.array! posts, :id, :body }
  x.report('after') { json.array! posts, :id, :body }

  x.hold! 'temp_array_memory'
  x.compare!
end
