module DefinesConstants
  def define_class(class_name, base = Object, &)
    class_name = class_name.to_s.camelize
    klass = Class.new(base)
    define_constant(class_name, klass)
    klass.class_eval(&) if block_given?
    klass
  end

  def define_constant(path, value)
    stub_const(path, value)
  end
end
