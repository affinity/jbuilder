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
posts = 3.times.map { Post.new(it, "Post ##{it}") }

Benchmark.ips do |x|
  x.report('before') do |n|
    n.times { json.array! posts, partial: "post", as: :post }
  end

  x.report('after') do |n|
    n.times { json.array! posts, partial: "post", as: :post }
  end

  x.hold! 'temp_array_results_ips'
  x.compare!
end

json = JbuilderTemplate.new view

Benchmark.memory do |x|
  x.report('before') do
    json.array! posts, partial: "post", as: :post
  end

  x.report('after') do
    json.array! posts, partial: "post", as: :post
  end

  x.hold! 'temp_array_results_memory'
  x.compare!
end
