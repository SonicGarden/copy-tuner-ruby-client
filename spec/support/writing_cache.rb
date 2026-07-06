class WritingCache
  FLUSHED = 'flushed'.freeze

  def flush
    File.write(path, FLUSHED)
  end

  def written?
    File.exist?(path) && File.read(path) == FLUSHED
  end

  private

  def path
    File.join(PROJECT_ROOT, 'tmp', 'written_cache')
  end
end
