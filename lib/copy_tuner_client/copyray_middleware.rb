# cf) xray-rails : xray/middleware.rb

require 'copy_tuner_client/copyray/rewriter'

module CopyTunerClient
  class CopyrayMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      CopyTunerClient::TranslationLog.clear
      status, headers, response = @app.call(env)
      if html_headers?(status, headers) && body = response_body(response)
        csp_nonce = env['action_dispatch.content_security_policy_nonce'] || env['secure_headers_content_security_policy_nonce']
        # NOTE: CSS/JS 挿入の前に Rewriter を通す。serialize 後も </body> は必ず出力されるので
        # append_to_html_body の rindex は機能し、CSS/JS タグはトークン非含有なので二重処理も起きない。
        # NOTE: skipped は data-copyray-key を付与できなかったこと（巨大DOM/Nokogiri例外）を表す。
        # JS にこれを伝え、オーバーレイ非対応である旨をツールバーで案内させる。
        body, skipped = CopyTunerClient::Copyray::Rewriter.rewrite(body)
        body = append_js(body, csp_nonce, skipped: skipped)
        content_length = body.bytesize.to_s
        headers['Content-Length'] = content_length
        # maintains compatibility with other middlewares
        if defined?(ActionDispatch::Response::RackBody) && ActionDispatch::Response::RackBody === response
          ActionDispatch::Response.new(status, headers, [body]).to_a
        else
          [status, headers, [body]]
        end
      else
        [status, headers, response]
      end
    end

    private

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
      append_to_html_body(html, helpers.javascript_include_tag('copytuner', type: 'module', crossorigin: 'anonymous', nonce: csp_nonce))
    end

    def append_to_html_body(html, content)
      content = content.html_safe if content.respond_to?(:html_safe)
      return html unless html.include?('</body>')

      position = html.rindex('</body>')
      html.insert(position, content + "\n")
    end

    def file?(headers)
      headers["Content-Transfer-Encoding"] == 'binary'
    end

    def html_headers?(status, headers)
      [200, 422].include?(status) &&
      headers['Content-Type'] &&
      headers['Content-Type'].include?('text/html') &&
      !file?(headers)
    end

    def response_body(response)
      body = +''
      response.each { |s| body << s.to_s }
      body
    end
  end
end
