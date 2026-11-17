module CopyTunerClient
  # Raised when an error occurs while contacting the CopyTuner server. This is
  # raised by {Client} and generally rescued by {Cache}. The application will
  # not encounter this error. Polling will continue even if this error is raised.
  class ConnectionError < StandardError
  end

  # 設定された認証情報（api_key / s3_path_token）が拒否されたことを表す例外の基底クラス
  class InvalidCredential < StandardError
  end

  # upload / deploy で api_key が CopyTuner サーバに認識されなかったときの例外
  class InvalidApiKey < InvalidCredential
  end

  # download で s3_path_token のパスに S3 の JSON が見つからなかったときの例外
  class InvalidS3PathToken < InvalidCredential
  end

  class IgnoredKey < StandardError
  end
end
