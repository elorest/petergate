require 'rails/generators'
require 'rails/generators/rails/scaffold_controller/scaffold_controller_generator'

module Rails
  module Generators
    class ScaffoldControllerWithAccessGenerator < ScaffoldControllerGenerator
      source_root File.expand_path("../templates", __FILE__)

      protected

      def attributes_params
        "#{singular_table_name}_params"
      end
    end
  end
end
