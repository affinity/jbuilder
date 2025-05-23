# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/rails/scaffold_controller/scaffold_controller_generator'

module Rails
  module Generators
    class ScaffoldControllerGenerator
      source_paths << File.expand_path('templates', __dir__)

      hook_for :jbuilder, type: :boolean, default: true

      private

      unless private_method_defined? :permitted_params
        def permitted_params
          attributes_names.map { |name| ":#{name}" }.join(', ')
        end
      end
    end
  end
end
