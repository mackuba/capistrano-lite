# frozen_string_literal: true

module Minestrone
  module Deploy
    module SCM
      def self.new(scm, config = {})
        scm_file = "minestrone/recipes/deploy/scm/#{scm}"
        require(scm_file)

        scm_const = scm.to_s.capitalize.gsub(/_(.)/) { $1.upcase }

        if const_defined?(scm_const)
          const_get(scm_const).new(config)
        else
          raise Minestrone::Error, "could not find `#{name}::#{scm_const}' in `#{scm_file}'"
        end
      rescue LoadError
        raise Minestrone::Error, "could not find any SCM named `#{scm}'"
      end
    end
  end
end
