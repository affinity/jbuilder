# frozen_string_literal: true

require 'benchmark/ips'
require 'benchmark/memory'
require_relative '../../lib/jbuilder'
require_relative '../../lib/jbuilder/jbuilder_template'

json = JbuilderTemplate.new nil
array = [1, 2, 3]

Benchmark.ips do |x|
  x.report('before') do |n|
    n.times do
      json.set! :foo, array do |item|
        json.set! :bar, item
      end
    end
  end
  x.report('after') do |n|
    n.times do
      json.set! :foo, array do |item|
        json.set! :bar, item
      end
    end
  end

  x.hold! 'temp_set_ips'
  x.compare!
end

json = JbuilderTemplate.new nil

Benchmark.memory do |x|
  x.report('before') do
    json.set! :foo, array do |item|
      json.set! :bar, item
    end
  end
  x.report('after') do
    json.set! :foo, array do |item|
      json.set! :bar, item
    end
  end

  x.hold! 'temp_set_memory'
  x.compare!
end
