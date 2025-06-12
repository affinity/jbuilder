# frozen_string_literal: true

require 'benchmark/ips'
require 'benchmark/memory'
require_relative 'setup'

POST_PARTIAL = <<-JBUILDER
  json.extract! post, :id, :body
JBUILDER

PARTIALS = { "_post.json.jbuilder" => POST_PARTIAL }

Post = Struct.new(:id, :body)

view = build_view(fixtures: PARTIALS)
json = JbuilderTemplate.new view
post = Post.new(1, "Post ##{1}")

Benchmark.ips do |x|
  x.report('before') do |times|
    times.times { json.partial! "post", post: post }
  end

  x.report('after') do |times|
    times.times { json.partial! "post", post: post }
  end

  x.hold! 'temp_partial_results_ips'
  x.compare!
end

Benchmark.memory do |x|
  x.report('before') do
    100.times { json.partial! "post", post: post }
  end

  x.report('after') do
    100.times { json.partial! "post", post: post }
  end

  x.hold! 'temp_partial_results_memory'
  x.compare!
end
