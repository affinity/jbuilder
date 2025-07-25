# frozen_string_literal: true

require 'active_support'
require 'jbuilder/jbuilder'
require 'jbuilder/blank'
require 'jbuilder/key_formatter'
require 'jbuilder/errors'
require 'jbuilder/version'
require 'json'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/object/blank'

class Jbuilder
  @@key_formatter = nil
  @@ignore_nil    = false
  @@deep_format_keys = false

  def initialize(
    key_formatter: @@key_formatter,
    ignore_nil: @@ignore_nil,
    deep_format_keys: @@deep_format_keys,
    &block
  )
    @attributes = {}
    @key_formatter = key_formatter
    @ignore_nil = ignore_nil
    @deep_format_keys = deep_format_keys

    yield self if block
  end

  # Yields a builder and automatically turns the result into a JSON string
  def self.encode(*args, &block)
    new(*args, &block).target!
  end

  BLANK = Blank.new.freeze
  EMPTY_ARRAY = [].freeze
  private_constant :BLANK, :EMPTY_ARRAY

  def set!(key, value = BLANK, *args, &block)
    _set(key, value, args, &block)
  end

  # Specifies formatting to be applied to the key. Passing in a name of a function
  # will cause that function to be called on the key.  So :upcase will upper case
  # the key.  You can also pass in lambdas for more complex transformations.
  #
  # Example:
  #
  #   json.key_format! :upcase
  #   json.author do
  #     json.name "David"
  #     json.age 32
  #   end
  #
  #   { "AUTHOR": { "NAME": "David", "AGE": 32 } }
  #
  # You can pass parameters to the method using a hash pair.
  #
  #   json.key_format! camelize: :lower
  #   json.first_name "David"
  #
  #   { "firstName": "David" }
  #
  # Lambdas can also be used.
  #
  #   json.key_format! ->(key){ "_" + key }
  #   json.first_name "David"
  #
  #   { "_first_name": "David" }
  #
  def key_format!(...)
    @key_formatter = KeyFormatter.new(...)
  end

  # Same as the instance method key_format! except sets the default.
  def self.key_format(...)
    @@key_formatter = KeyFormatter.new(...)
  end

  # If you want to skip adding nil values to your JSON hash. This is useful
  # for JSON clients that don't deal well with nil values, and would prefer
  # not to receive keys which have null values.
  #
  # Example:
  #   json.ignore_nil! false
  #   json.id User.new.id
  #
  #   { "id": null }
  #
  #   json.ignore_nil!
  #   json.id User.new.id
  #
  #   {}
  #
  def ignore_nil!(value = true)
    @ignore_nil = value
  end

  # Same as instance method ignore_nil! except sets the default.
  def self.ignore_nil(value = true)
    @@ignore_nil = value
  end

  # Deeply apply key format to nested hashes and arrays passed to
  # methods like set!, merge! or array!.
  #
  # Example:
  #
  #   json.key_format! camelize: :lower
  #   json.settings({some_value: "abc"})
  #
  #   { "settings": { "some_value": "abc" }}
  #
  #   json.key_format! camelize: :lower
  #   json.deep_format_keys!
  #   json.settings({some_value: "abc"})
  #
  #   { "settings": { "someValue": "abc" }}
  #
  def deep_format_keys!(value = true)
    @deep_format_keys = value
  end

  # Same as instance method deep_format_keys! except sets the default.
  def self.deep_format_keys(value = true)
    @@deep_format_keys = value
  end

  # Turns the current element into an array and yields a builder to add a hash.
  #
  # Example:
  #
  #   json.comments do
  #     json.child! { json.content "hello" }
  #     json.child! { json.content "world" }
  #   end
  #
  #   { "comments": [ { "content": "hello" }, { "content": "world" } ]}
  #
  # More commonly, you'd use the combined iterator, though:
  #
  #   json.comments(@post.comments) do |comment|
  #     json.content comment.formatted_content
  #   end
  def child!
    @attributes = [] unless ::Array === @attributes
    @attributes << _scope{ yield self }
  end

  # Turns the current element into an array and iterates over the passed collection, adding each iteration as
  # an element of the resulting array.
  #
  # Example:
  #
  #   json.array!(@people) do |person|
  #     json.name person.name
  #     json.age calculate_age(person.birthday)
  #   end
  #
  #   [ { "name": David", "age": 32 }, { "name": Jamie", "age": 31 } ]
  #
  # You can use the call syntax instead of an explicit extract! call:
  #
  #   json.(@people) { |person| ... }
  #
  # It's generally only needed to use this method for top-level arrays. If you have named arrays, you can do:
  #
  #   json.people(@people) do |person|
  #     json.name person.name
  #     json.age calculate_age(person.birthday)
  #   end
  #
  #   { "people": [ { "name": David", "age": 32 }, { "name": Jamie", "age": 31 } ] }
  #
  # If you omit the block then you can set the top level array directly:
  #
  #   json.array! [1, 2, 3]
  #
  #   [1,2,3]
  def array!(collection = EMPTY_ARRAY, *attributes, &block)
    _array(collection, attributes, &block)
  end

  # Extracts the mentioned attributes or hash elements from the passed object and turns them into attributes of the JSON.
  #
  # Example:
  #
  #   @person = Struct.new(:name, :age).new('David', 32)
  #
  #   or you can utilize a Hash
  #
  #   @person = { name: 'David', age: 32 }
  #
  #   json.extract! @person, :name, :age
  #
  #   { "name": David", "age": 32 }, { "name": Jamie", "age": 31 }
  #
  # You can also use the call syntax instead of an explicit extract! call:
  #
  #   json.(@person, :name, :age)
  def extract!(object, *attributes)
    _extract object, attributes
  end

  def call(object, *attributes, &block)
    if ::Kernel.block_given?
      _array object, &block
    else
      _extract object, attributes
    end
  end

  # Returns the nil JSON.
  def nil!
    @attributes = nil
  end

  alias_method :null!, :nil!

  # Returns the attributes of the current builder.
  def attributes!
    @attributes
  end

  # Merges hash, array, or Jbuilder instance into current builder.
  def merge!(object)
    hash_or_array = ::Jbuilder === object ? object.attributes! : object
    @attributes = _merge_values(@attributes, _format_keys(hash_or_array))
  end

  # Encodes the current builder as JSON.
  def target!
    @attributes.to_json
  end

  private

  alias_method :method_missing, :set!

  def _set(key, value = BLANK, attributes = nil, &block)
    result = if block
      if _blank?(value)
        # json.comments { ... }
        # { "comments": ... }
        _merge_block key, &block
      else
        # json.comments @post.comments { |comment| ... }
        # { "comments": [ { ... }, { ... } ] }
        _scope { _array value, &block }
      end
    elsif attributes.blank?
      if ::Jbuilder === value
        # json.age 32
        # json.person another_jbuilder
        # { "age": 32, "person": { ...  }
        _format_keys(value.attributes!)
      else
        # json.age 32
        # { "age": 32 }
        _format_keys(value)
      end
    elsif _is_collection?(value)
      # json.comments @post.comments, :content, :created_at
      # { "comments": [ { "content": "hello", "created_at": "..." }, { "content": "world", "created_at": "..." } ] }
      _scope { _array value, attributes }
    else
      # json.author @post.creator, :name, :email_address
      # { "author": { "name": "David", "email_address": "david@loudthinking.com" } }
      _merge_block(key) { _extract value, attributes }
    end

    _set_value key, result
  end

  def _array(collection = EMPTY_ARRAY, attributes = nil, &block)
    array = if collection.nil?
      EMPTY_ARRAY
    elsif block
      _map_collection(collection, &block)
    elsif attributes.present?
      _map_collection(collection) { |element| _extract element, attributes }
    else
      _format_keys(collection.to_a)
    end

    @attributes = _merge_values(@attributes, array)
  end

  def _extract(object, attributes)
    if ::Hash === object
      _extract_hash_values(object, attributes)
    else
      _extract_method_values(object, attributes)
    end
  end

  def _extract_hash_values(object, attributes)
    attributes.each{ |key| _set_value key, _format_keys(object.fetch(key)) }
  end

  def _extract_method_values(object, attributes)
    attributes.each{ |key| _set_value key, _format_keys(object.public_send(key)) }
  end

  def _merge_block(key)
    current_value = _blank? ? BLANK : @attributes.fetch(_key(key), BLANK)
    ::Kernel.raise NullError.build(key) if current_value.nil?
    new_value = _scope{ yield self }
    _merge_values(current_value, new_value)
  end

  def _merge_values(current_value, updates)
    if _blank?(updates)
      current_value
    elsif _blank?(current_value) || updates.nil? || current_value.empty? && ::Array === updates
      updates
    elsif ::Array === current_value && ::Array === updates
      current_value + updates
    elsif ::Hash === current_value && ::Hash === updates
      current_value.deep_merge(updates)
    else
      ::Kernel.raise MergeError.build(current_value, updates)
    end
  end

  def _key(key)
    if @key_formatter
      @key_formatter.format(key)
    elsif key.is_a?(::Symbol)
      key.name
    else
      key.to_s
    end
  end

  def _format_keys(hash_or_array)
    return hash_or_array unless @deep_format_keys

    if ::Array === hash_or_array
      hash_or_array.map { |value| _format_keys(value) }
    elsif ::Hash === hash_or_array
      ::Hash[hash_or_array.collect { |k, v| [_key(k), _format_keys(v)] }]
    else
      hash_or_array
    end
  end

  def _set_value(key, value)
    ::Kernel.raise NullError.build(key) if @attributes.nil?
    ::Kernel.raise ArrayError.build(key) if ::Array === @attributes
    return if @ignore_nil && value.nil? or _blank?(value)
    @attributes = {} if _blank?
    @attributes[_key(key)] = value
  end

  def _map_collection(collection)
    collection.map do |element|
      _scope{ yield element }
    end - [BLANK]
  end

  def _scope
    parent_attributes, parent_formatter, parent_deep_format_keys = @attributes, @key_formatter, @deep_format_keys
    @attributes = BLANK
    yield
    @attributes
  ensure
    @attributes, @key_formatter, @deep_format_keys = parent_attributes, parent_formatter, parent_deep_format_keys
  end

  def _is_collection?(object)
    object.respond_to?(:map) && object.respond_to?(:count) && !(::Struct === object)
  end

  def _blank?(value=@attributes)
    BLANK == value
  end
end

require 'jbuilder/railtie' if defined?(Rails)
