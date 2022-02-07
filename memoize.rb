#!/usr/bin/env ruby
# https://engineering.gusto.com/memoization-in-ruby-made-easy/

# class FibonacciCalculator
#   include Memoize

#   memoize
#   def calculate(n)
#     return n if (0..1).include?(n)
#     calculate(n - 1) + calculate(n - 2)
#   end

# end

module Memoize
  class Memoizer
    attr_reader :context, :method

    def initialize(context, method)
      @context = context
      @method = method
    end

    def call(*args, &block)
      return cache[[args, block]] if cache.has_key?([args, block])
      cache[[args, block]] = context.send(method, *args, &block)
    end

    def cache
      @cache ||= {}
    end
  end

  def self.included(klass)
    klass.extend(ClassMethods)
  end

  module ClassMethods
    def memoize
      @memoized = true
    end

    def method_added(method_name)
      if @memoized
        @memoized = false

        unmemoized_method_name = :"unmemoized_#{method_name}"

        memoizer_name = :"memoizer_for_#{method_name}"
        define_method memoizer_name do
          memoizer = instance_variable_get "@#{memoizer_name}"
          if memoizer
            memoizer
          else
            instance_variable_set "@#{memoizer_name}", Memoizer.new(self, unmemoized_method_name)
          end
        end

        alias_method unmemoized_method_name, method_name

        define_method method_name do |*args, &block|
          send(memoizer_name).call(*args, &block)
        end

      end
    end
  end
end
