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
  x.report('before') do |n|
    n.times { json.set! post, partial: "post", as: :post }
  end

  x.report('after') do |n|
    n.times { json.set! post, partial: "post", as: :post }
  end

  x.hold! 'temp_set_results_ips'
  x.compare!
end

json = JbuilderTemplate.new view

Benchmark.memory do |x|
  x.report('before') do
    json.set! :post, post, partial: "post", as: :post
  end

  x.report('after') do
    json.set! :post, post, partial: "post", as: :post
  end

  x.hold! 'temp_set_results_memory'
  x.compare!
end
