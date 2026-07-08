# cf) xray-rails : xray/middleware.rb

require 'copy_tuner_client/copyray/rewriter'

module CopyTunerClient
  # レスポンス HTML を Rewriter に通し、マーカートークンを data-copyray-key 属性へ変換する Rack middleware
  class CopyrayMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      CopyTunerClient::TranslationLog.clear
      status, headers, response = @app.call(env)
      if rewritable?(status, headers) && (body = response_body(response))
        rewrite_response(env, status, headers, body, response)
      else
        [status, headers, response]
      end
    end

    private

    def rewrite_response(env, status, headers, body, response)
      csp_nonce =
        env.fetch('action_dispatch.content_security_policy_nonce') do
          env['secure_headers_content_security_policy_nonce']
        end
      # NOTE: CSS/JS 挿入の前に Rewriter を通す。serialize 後も </body> は必ず出力されるので
      # append_to_html_body の rindex は機能し、CSS/JS タグはトークン非含有なので二重処理も起きない。
      # NOTE: skipped は data-copyray-key を付与できなかったこと（巨大DOM/Nokogiri例外）を表す。
      # JS にこれを伝え、オーバーレイ非対応である旨をツールバーで案内させる。
      # NOTE: turbo stream はページ断片なので fragment パーサで走査する（html/body ラッパを付けない）。
      turbo_stream = turbo_stream?(headers)
      body, skipped = CopyTunerClient::Copyray::Rewriter.rewrite(body, fragment: turbo_stream)
      # NOTE: ブートストラップ JS はフルページ読み込み時に一度だけ挿入すればよい。turbo stream 断片には
      # 挿入先の </body> も無く、既に初期化済みのページへマージされるだけなので挿入しない。
      body = append_js(body, csp_nonce, skipped:) unless turbo_stream
      headers['Content-Length'] = body.bytesize.to_s
      # maintains compatibility with other middlewares
      if defined?(ActionDispatch::Response::RackBody) && response.is_a?(ActionDispatch::Response::RackBody)
        ActionDispatch::Response.new(status, headers, [body]).to_a
      else
        [status, headers, [body]]
      end
    end

    def helpers
      ActionController::Base.helpers
    end

    def append_js(html, csp_nonce, skipped: false)
      json =
        if CopyTunerClient::TranslationLog.initialized?
          CopyTunerClient::TranslationLog.translations.to_json
        else
          '{}'
        end

      append_to_html_body(html, helpers.javascript_tag(<<~SCRIPT, nonce: csp_nonce))
        window.CopyTuner = {
          url: '#{CopyTunerClient.configuration.project_url}',
          data: #{json},
          keysSkipped: #{skipped},
        }
      SCRIPT
      tag = helpers.javascript_include_tag('copytuner', type: 'module', crossorigin: 'anonymous', nonce: csp_nonce)
      append_to_html_body(html, tag)
    end

    def append_to_html_body(html, content)
      content = content.html_safe if content.respond_to?(:html_safe)
      return html unless html.include?('</body>')

      position = html.rindex('</body>')
      html.insert(position, "#{content}\n")
    end

    def file?(headers)
      headers['Content-Transfer-Encoding'] == 'binary'
    end

    def rewritable?(status, headers)
      [200, 422].include?(status) &&
        headers['Content-Type'] &&
        (headers['Content-Type'].include?('text/html') || turbo_stream?(headers)) &&
        !file?(headers)
    end

    def turbo_stream?(headers)
      headers['Content-Type']&.include?('text/vnd.turbo-stream.html')
    end

    def response_body(response)
      body = +''
      response.each { |s| body << s.to_s }
      body
    end
  end
end
