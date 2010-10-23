module Measure
  class Quantity
    def initialize(value, unit)
      @value = value
      @unit = unit
    end
  end

  class Unit
    def initialize(name)
      @name = name
    end
  end

  module InstanceMethods
    def self.included(klass)
      klass.class_eval do
        alias __aref__ []  if instance_methods.include?(:[])

        def [](*args)
          if args[0].is_a?(Unit)
            Quantity.new(self, args[0])
          else
            __aref__(*args) if instance_methods.include?(:[])
          end
        end
      end
    end
  end
end

Fixnum.class_eval { include Measure::InstanceMethods }
Bignum.class_eval { include Measure::InstanceMethods }
Float.class_eval { include Measure::InstanceMethods }

module ScopeTest
  def self.method_missing(name, *args)
    case name
    when :cm, :in, :pt
      Measure::Unit.new(name)
    else
      super(name, *args)
    end
  end
end

ScopeTest.module_eval do
  p 1[cm]
end

