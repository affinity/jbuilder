# frozen_string_literal: true

require 'benchmark/ips'
require 'benchmark/memory'
require_relative '../../lib/jbuilder'
require_relative '../../lib/jbuilder/jbuilder_template'

Post = Struct.new(:id, :body)
json = JbuilderTemplate.new nil
array = [1, 2, 3]

Benchmark.ips do |x|
  x.report('before') do |n|
    n.times do
      json.array! array do |item|
      end
    end
  end
  x.report('after') do |n|
    n.times do
      json.array! array do |item|
      end
    end
  end

  x.hold! 'temp_array_ips'
  x.compare!
end

json = JbuilderTemplate.new nil

Benchmark.memory do |x|
  x.report('before') do
    json.array! array do |item|
    end
  end
  x.report('after') do
    json.array! array do |item|
    end
  end

  x.hold! 'temp_array_memory'
  x.compare!
end
