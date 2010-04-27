require 'bigfloat/bigfloat'

class BigFloat < Numeric
  VERSION = '0.0.1'

  DEFAULT_BASE = 2

  class << self
    alias __new__ new
    undef new
  end

  attr_reader :base

  def initialize(*args)
    check_opts(Hash === args.last ? args.pop : {})
    case args.length
    when 1
      case x = args.first
      when Integer
        @mantissa = x
        @exponent = 0
      when Float
        raise NotImplementedError
      when String
        raise NotImplementedError
      when BigFloat
        raise NotImplementedError
      end
    when 2
      raise NotImplementedError
    else
      raise ArgumentError, 'too many arguments'
    end
  end

  def accuracy
    raise NotImplementedError
  end

  def precision
    raise NotImplementedError
  end

  def ==(other)
    case other
    when Integer
      raise NotImplementedError
    when Float
      raise NotImplementedError
    when BigFloat
      raise NotImplementedError
    else
      return false
    end
  end

  private

  def check_opts(opts)
    @base = check_base(opts[:base] || DEFAULT_BASE)
  end

  def check_base(base)
    case base = Integer(base)
    when 2, 10
      return base
    else
      raise ArgumentError, "base is allowed only 2 or 10"
    end
  end
end

module Kernel
  def BigFloat(*args)
    BigFloat.__send__(:__new__, *args)
  end
end
