require "rails"
require "active_support/core_ext/array/access"
require "active_support/cache/memory_store"
require "active_support/json"
require "active_model"
require 'action_controller/railtie'
require 'action_view/railtie'
require "active_support/testing/autorun"
require "action_view/testing/resolvers"
require_relative '../../lib/jbuilder'
require_relative '../../lib/jbuilder/jbuilder_template'

# A lot of this was copied over from the `jbuilder_template_test.rb` file.

# Instantiate an Application in order to trigger the initializers
Class.new(Rails::Application) do
  config.secret_key_base = 'secret'
  config.eager_load = false
end.initialize!

# # Touch AV::Base in order to trigger :action_view on_load hook before running the tests
ActionView::Base.inspect

def build_view(fixtures:, assigns: {})
  resolver = ActionView::FixtureResolver.new(fixtures)
  lookup_context = ActionView::LookupContext.new([ resolver ], {}, [""])
  controller = ActionView::TestCase::TestController.new

  ActionView::Base.with_empty_template_cache.new(lookup_context, assigns, controller)
end
