module ClientSpecHelpers
  def reset_config
    CopyTunerClient.configuration = nil
    CopyTunerClient.configure(apply: false) do |config|
      config.api_key = 'abc123'
      config.s3_path_token = 'token123'
      config.s3_host = 'copy-tuner.com'
    end
  end
end
