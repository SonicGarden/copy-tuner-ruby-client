class WritingCache
  def flush
    File.write(path, object_id.to_s)
  end

  def written?
    IO.read(path) == object_id.to_s
  end

  private

  def path
    File.join(PROJECT_ROOT, 'tmp', 'written_cache')
  end
end
