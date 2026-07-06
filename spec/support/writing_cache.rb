class WritingCache
  def flush
    File.write(path, object_id.to_s)
  end

  def written?
    File.read(path) == object_id.to_s
  end

  private

  def path
    File.join(PROJECT_ROOT, 'tmp', 'written_cache')
  end
end
