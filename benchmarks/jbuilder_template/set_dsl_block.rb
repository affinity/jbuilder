# frozen_string_literal: true

require 'benchmark/ips'
require 'benchmark/memory'
require_relative '../../lib/jbuilder'
require_relative '../../lib/jbuilder/jbuilder_template'

json = JbuilderTemplate.new nil
object = { bar: 123 }

Benchmark.ips do |x|
  x.report('before') do |n|
    n.times do
      json.set! :foo do
        json.extract! object, :bar
      end
    end
  end
  x.report('after') do |n|
    n.times do
      json.set! :foo do
        json.extract! object, :bar
      end
    end
  end

  x.hold! 'temp_set_ips'
  x.compare!
end

json = JbuilderTemplate.new nil

Benchmark.memory do |x|
  x.report('before') do
    json.set! :foo do
      json.extract! object, :bar
    end
  end
  x.report('after') do
    json.set! :foo do
      json.extract! object, :bar
    end
  end

  x.hold! 'temp_set_memory'
  x.compare!
end
