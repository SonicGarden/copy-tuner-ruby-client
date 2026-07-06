class MiddlewareStack
  def initialize
    @middlewares = []
  end

  def use(klass, *)
    @middlewares << klass.new('fake_app', *)
  end

  def include?(klass)
    @middlewares.any? { |middleware| klass === middleware }
  end
end
