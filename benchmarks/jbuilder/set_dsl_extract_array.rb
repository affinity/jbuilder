# frozen_string_literal: true

require 'benchmark/ips'
require 'benchmark/memory'
require_relative '../../lib/jbuilder'

Post = Struct.new(:id, :body)
json = Jbuilder.new
posts = 3.times.map { Post.new(it, "Post ##{it}") }

Benchmark.ips do |x|
  x.report('before') do
    json.set! :posts, posts, :id, :body
  end
  x.report('after') do
    json.set! :posts, posts, :id, :body
  end

  x.hold! 'temp_array_ips'
  x.compare!
end

json = Jbuilder.new

Benchmark.memory do |x|
  x.report('before') do
    json.set! :posts, posts, :id, :body
  end
  x.report('after') do
    json.set! :posts, posts, :id, :body
  end

  x.hold! 'temp_array_memory'
  x.compare!
end
