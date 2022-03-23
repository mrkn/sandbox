class Effector
  TLS_KEY = "EFFECTOR_KEY_838861"

  def self.current
    Thread.current[TLS_KEY]
  end

  def self.handle(effect, &block)
    current.handle(effect, &block)
    nil
  end

  def self.perform(effect)
    current.perform(effect)
  end

  def self.run(&block)
    self.new.run(&block)
  end

  def initialize
    @handler = {}
  end

  def run(&block)
    @fiber = Fiber.new do
      old = Thread.current[TLS_KEY]
      Thread.current[TLS_KEY] = self
      block.call
    ensure
      Thread.current[TLS_KEY] = old
    end
    @fiber.resume
  end

  def handle(effect, &block)
    @handler[effect] = Fiber.new(&block)
  end

  def perform(effect)
    @handler[effect]&.resume(self)
  end

  def resume(value=nil)
    Fiber.yield(value)
  end
end


def get_name(user)
  user[:name] || Effector.perform("ask_name")
end

def make_friends(user1, user2)
  p user2: get_name(user2)
  p user1: get_name(user1)
end

arya = { name: nil }
gendry = { name: 'Gendry' }

Effector.run do
  Effector.handle("ask_name") do |effector|
    effector.resume("Arya Stark")
  end

  make_friends(arya, gendry)
end

Effector.run do
  Effector.handle("foo") do |effector|
    p 2
    effector.resume
  end

  p 1
  Effector.perform("foo")
  p 3
end
