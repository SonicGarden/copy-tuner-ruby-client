class FakeHtmlSafeString < String
  def initialize(*)
    super
    @html_safe = false
  end

  def html_safe
    dup.html_safe!
  end

  def html_safe!
    @html_safe = true
    self
  end

  def html_safe?
    @html_safe
  end
end
