# frozen_string_literal: true

require 'jbuilder/jbuilder'
require 'jbuilder/collection_renderer'
require 'action_dispatch/http/mime_type'
require 'active_support/cache'

class JbuilderTemplate < Jbuilder
  class << self
    attr_accessor :template_lookup_options
  end

  self.template_lookup_options = { handlers: [:jbuilder] }

  def initialize(context, options = nil)
    @context = context
    @cached_root = nil

    options.nil? ? super() : super(**options)
  end

  # Generates JSON using the template specified with the `:partial` option. For example, the code below will render
  # the file `views/comments/_comments.json.jbuilder`, and set a local variable comments with all this message's
  # comments, which can be used inside the partial.
  #
  # Example:
  #
  #   json.partial! 'comments/comments', comments: @message.comments
  #
  # There are multiple ways to generate a collection of elements as JSON, as ilustrated below:
  #
  # Example:
  #
  #   json.array! @posts, partial: 'posts/post', as: :post
  #
  #   # or:
  #   json.partial! 'posts/post', collection: @posts, as: :post
  #
  #   # or:
  #   json.partial! partial: 'posts/post', collection: @posts, as: :post
  #
  #   # or:
  #   json.comments @post.comments, partial: 'comments/comment', as: :comment
  #
  # Aside from that, the `:cached` options is available on Rails >= 6.0. This will cache the rendered results
  # effectively using the multi fetch feature.
  #
  # Example:
  #
  #   json.array! @posts, partial: "posts/post", as: :post, cached: true
  #
  #   json.comments @post.comments, partial: "comments/comment", as: :comment, cached: true
  #
  def partial!(partial_or_model = nil, **options)
    if options.empty? && _is_active_model?(partial_or_model)
      _render_active_model_partial partial_or_model
    else
      options[:partial] = partial_or_model if partial_or_model
      _render_partial_with_options options
    end
  end

  # Caches the json constructed within the block passed. Has the same signature as the `cache` helper
  # method in `ActionView::Helpers::CacheHelper` and so can be used in the same way.
  #
  # Example:
  #
  #   json.cache! ['v1', @person], expires_in: 10.minutes do
  #     json.extract! @person, :name, :age
  #   end
  def cache!(key=nil, options={})
    if @context.controller.perform_caching
      value = _cache_fragment_for(key, options) do
        _scope { yield self }
      end

      merge! value
    else
      yield
    end
  end

  # Caches the json structure at the root using a string rather than the hash structure. This is considerably
  # faster, but the drawback is that it only works, as the name hints, at the root. So you cannot
  # use this approach to cache deeper inside the hierarchy, like in partials or such. Continue to use #cache! there.
  #
  # Example:
  #
  #   json.cache_root! @person do
  #     json.extract! @person, :name, :age
  #   end
  #
  #   # json.extra 'This will not work either, the root must be exclusive'
  def cache_root!(key=nil, options={})
    if @context.controller.perform_caching
      ::Kernel.raise "cache_root! can't be used after JSON structures have been defined" if @attributes.present?

      @cached_root = _cache_fragment_for([ :root, key ], options) { yield; target! }
    else
      yield
    end
  end

  # Conditionally caches the json depending in the condition given as first parameter. Has the same
  # signature as the `cache` helper method in `ActionView::Helpers::CacheHelper` and so can be used in
  # the same way.
  #
  # Example:
  #
  #   json.cache_if! !admin?, @person, expires_in: 10.minutes do
  #     json.extract! @person, :name, :age
  #   end
  def cache_if!(condition, *args, &block)
    condition ? cache!(*args, &block) : yield
  end

  def target!
    @cached_root || super
  end

  def array!(collection = EMPTY_ARRAY, *args)
    options = args.first

    if _partial_options?(options)
      options[:collection] = collection
      _render_partial_with_options options
    elsif ::Kernel.block_given?
      _array(collection, args) { |x| yield x }
    else
      _array collection, args
    end
  end

  def set!(name, object = BLANK, *args)
    options = args.first

    if _partial_options?(options)
      _set_inline_partial name, object, options
    elsif ::Kernel.block_given?
      _set(name, object, args) { |x| yield x }
    else
      _set(name, object, args)
    end
  end

  private

  alias_method :method_missing, :set!

  def _render_partial_with_options(options)
    options[:locals] ||= options.except(:partial, :as, :collection, :cached)
    options[:handlers] ||= ::JbuilderTemplate.template_lookup_options[:handlers]
    as = options[:as]

    if as && options.key?(:collection)
      collection = options.delete(:collection) || EMPTY_ARRAY
      partial = options.delete(:partial)
      options[:locals][:json] = self
      collection = EnumerableCompat.new(collection) if collection.respond_to?(:count) && !collection.respond_to?(:size)

      if options.has_key?(:layout)
        ::Kernel.raise ::NotImplementedError, "The `:layout' option is not supported in collection rendering."
      end

      if options.has_key?(:spacer_template)
        ::Kernel.raise ::NotImplementedError, "The `:spacer_template' option is not supported in collection rendering."
      end

      if collection.present?
        results = CollectionRenderer
          .new(@context.lookup_context, options) { |&block| _scope(&block) }
          .render_collection_with_partial(collection, partial, @context, nil)

        _array if results.respond_to?(:body) && results.body.nil?
      else
        _array
      end
    else
      _render_partial options
    end
  end

  def _render_partial(options)
    options[:locals][:json] = self
    # Prevents memory allocation for an empty Hash by providing nil as the second argument.
    @context.render options, nil
  end

  def _cache_fragment_for(key, options, &block)
    key = _cache_key(key, options)
    _read_fragment_cache(key, options) || _write_fragment_cache(key, options, &block)
  end

  def _read_fragment_cache(key, options = nil)
    @context.controller.instrument_fragment_cache :read_fragment, key do
      ::Rails.cache.read(key, options)
    end
  end

  def _write_fragment_cache(key, options = nil)
    @context.controller.instrument_fragment_cache :write_fragment, key do
      yield.tap do |value|
        ::Rails.cache.write(key, value, options)
      end
    end
  end

  def _cache_key(key, options)
    name_options = options.slice(:skip_digest, :virtual_path)
    key = _fragment_name_with_digest(key, name_options)

    if @context.respond_to?(:combined_fragment_cache_key)
      key = @context.combined_fragment_cache_key(key)
    else
      key = url_for(key).split('://', 2).last if ::Hash === key
    end

    ::ActiveSupport::Cache.expand_cache_key(key, :jbuilder)
  end

  def _fragment_name_with_digest(key, options)
    if @context.respond_to?(:cache_fragment_name)
      @context.cache_fragment_name(key, **options)
    else
      key
    end
  end

  def _partial_options?(options)
    ::Hash === options && options.key?(:as) && options.key?(:partial)
  end

  def _is_active_model?(object)
    object.respond_to?(:to_partial_path) && object.class.respond_to?(:model_name)
  end

  def _set_inline_partial(name, object, options)
    value = if object.nil?
      EMPTY_ARRAY
    elsif _is_collection?(object)
      _scope do
        options[:collection] = object
        _render_partial_with_options options
      end
    else
      _scope do
        options[:locals] = { options[:as] => object }
        _render_partial_with_options options
      end
    end

    _set_value name, value
  end

  def _render_active_model_partial(object)
    @context.render object, json: self
  end
end

class JbuilderHandler
  cattr_accessor :default_format
  self.default_format = :json

  def self.call(template, source = nil)
    source ||= template.source
    # this juggling is required to keep line numbers right in the error
    %{__already_defined = defined?(json); json||=JbuilderTemplate.new(self); #{source};
      json.target! unless (__already_defined && __already_defined != "method")}
  end
end
