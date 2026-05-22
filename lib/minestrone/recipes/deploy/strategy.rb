# frozen_string_literal: true

module Minestrone
  module Deploy
    module Strategy
      def self.new(strategy, config = {})
        strategy_file = "minestrone/recipes/deploy/strategy/#{strategy}"
        strategy_const = strategy.to_s.capitalize.gsub(/_(.)/) { $1.upcase }

        require(strategy_file) unless const_defined?(strategy_const)

        if const_defined?(strategy_const)
          const_get(strategy_const).new(config)
        else
          raise Minestrone::Error, "could not find `#{name}::#{strategy_const}' in `#{strategy_file}'"
        end
      rescue LoadError
        raise Minestrone::Error, "could not find any strategy named `#{strategy}'"
      end
    end
  end
end
