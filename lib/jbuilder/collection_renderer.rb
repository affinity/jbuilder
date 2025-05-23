# frozen_string_literal: true

require 'delegate'
require 'active_support/concern'
require 'action_view'
require 'action_view/renderer/collection_renderer'

class Jbuilder
  module CollectionRenderable # :nodoc:
    extend ActiveSupport::Concern

    class_methods do
      def supported?
        superclass.private_method_defined?(:build_rendered_template) &&
          superclass.private_method_defined?(:build_rendered_collection)
      end
    end

    private

    def build_rendered_template(content, template, _layout = nil)
      super(content || json.attributes!, template)
    end

    def build_rendered_collection(templates, _spacer)
      json.merge!(templates.map(&:body))
    end

    def json
      @options[:locals].fetch(:json)
    end

    class ScopedIterator < ::SimpleDelegator # :nodoc:
      include Enumerable

      def initialize(obj, scope)
        super(obj)
        @scope = scope
      end

      # Rails 6.0 support:
      def each
        return enum_for(:each) unless block_given?

        __getobj__.each do |object|
          @scope.call { yield(object) }
        end
      end

      # Rails 6.1 support:
      def each_with_info
        return enum_for(:each_with_info) unless block_given?

        __getobj__.each_with_info do |object, info|
          @scope.call { yield(object, info) }
        end
      end
    end

    private_constant :ScopedIterator
  end

  class CollectionRenderer < ::ActionView::CollectionRenderer # :nodoc:
    include CollectionRenderable

    def initialize(lookup_context, options, &scope)
      super(lookup_context, options)
      @scope = scope
    end

    private

    def collection_with_template(view, template, layout, collection)
      super(view, template, layout, ScopedIterator.new(collection, @scope))
    end
  end

  class EnumerableCompat < ::SimpleDelegator
    # Rails 6.1 requires this.
    def size(*args, &block)
      __getobj__.count(*args, &block)
    end
  end
end
