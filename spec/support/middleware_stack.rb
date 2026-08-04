# ActionDispatch::MiddlewareStack の挿入 API を模した fake（挿入順序と引数を検証するため）
class MiddlewareStack
  Entry = Struct.new(:klass, :args)

  def initialize(existing = [])
    @middlewares = existing.map { |klass| Entry.new(klass, []) }
  end

  def use(klass, *args)
    @middlewares << Entry.new(klass, args)
  end

  def insert_before(target, klass, *args)
    index = index_of!(target, 'before')
    @middlewares.insert(index, Entry.new(klass, args))
  end

  def insert_after(target, klass, *args)
    index = index_of!(target, 'after')
    @middlewares.insert(index + 1, Entry.new(klass, args))
  end

  def include?(klass)
    classes.include?(klass)
  end

  def classes
    @middlewares.map(&:klass)
  end

  def index(klass)
    classes.index(klass)
  end

  def args_for(klass)
    @middlewares.find { |entry| entry.klass == klass }&.args
  end

  private

  def index_of!(target, where)
    index = classes.index(target)
    raise "No such middleware to insert #{where}: #{target.inspect}" if index.nil?

    index
  end
end
