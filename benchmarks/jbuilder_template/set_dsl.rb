# frozen_string_literal: true

require 'benchmark/ips'
require 'benchmark/memory'
require_relative '../../lib/jbuilder'
require_relative '../../lib/jbuilder/jbuilder_template'

json = JbuilderTemplate.new nil

Benchmark.ips do |x|
  x.report('before') do |n|
    n.times { json.set! :foo, :bar }
  end
  x.report('after') do |n|
    n.times { json.set! :foo, :bar }
  end

  x.hold! 'temp_set_ips'
  x.compare!
end

json = JbuilderTemplate.new nil

Benchmark.memory do |x|
  x.report('before') { json.set! :foo, :bar }
  x.report('after') { json.set! :foo, :bar }

  x.hold! 'temp_set_memory'
  x.compare!
end
