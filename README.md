CopyTuner Client
=================

[![Build Status](https://travis-ci.org/SonicGarden/copy-tuner-ruby-client.svg?branch=master)](https://travis-ci.org/SonicGarden/copy-tuner-ruby-client)

## Getting started

Add it to your Gemfile

```
gem 'copy_tuner_client'
```

Create config/initializers/copy_tuner.rb

```
CopyTunerClient.configure do |config|
  config.api_key = 'YOUR-API-KEY'
  config.project_id = 77
  config.host = 'COPY-TUNER-HOST-NAME'
  config.html_escape = true

  # I18n keys and messages will be sent to server if the locale matches
  config.locales = [:ja, :en]
end
```

## CopyTunerの翻訳ファイルをymlとして出力する

該当のRailsプロジェクトで下記のrakeを実行する

```
bundle exec rake copy_tuner:export
```

これで、`config/locales/copy_tuner.yml` に翻訳ファイルが作成されます。

## MCPサーバー

このgemには、Model Context Protocol (MCP) サーバーが含まれており、AI開発ツール（copilot agentなど）から翻訳データにアクセスできます。

### VSCodeでの設定

`.vscode/mcp.json` に以下を追加：

```json
{
  "servers": {
    "copy-tuner": {
      "type": "stdio",
      "command": "bundle",
      "args": [
        "exec",
        "copy-tuner-mcp"
      ],
      "cwd": "${workspaceFolder}"
    }
  }
}
```

### 利用可能な機能

#### Tools（ツール）
- **search_key**: i18nキーでの検索
  - パラメータ: `query` (必須), `locale` (デフォルト: 'ja')
  - 例: `user.name` が含まれるi18nキーを検索
- **search_translations**: 翻訳内容での検索
  - パラメータ: `query` (必須), `locale` (デフォルト: 'ja')
  - 例: 「ユーザー」という文字列を含む翻訳を検索
- **create_i18n_key**: 新しいi18nキーの作成（非同期）
  - パラメータ: `key` (必須), `translations` (ロケール・値のペア配列)
  - 例: 新しい翻訳キーを複数の言語で同時登録
- **get_locales**: 利用可能なロケール一覧の取得
  - パラメータ: なし
  - 現在設定されているロケール情報を取得
- **get_edit_url**: 登録済みキーの編集画面URLを取得
  - パラメータ: `key` (必須)
  - CopyTuner管理画面での編集URLを生成

#### Resources（リソース）
- **個別翻訳の取得**: `copytuner://projects/PROJECT_ID/translations/{locale}/{key}`
  - 例: `copytuner://projects/77/translations/ja/user.name`
  - 特定のキーとロケールに対する翻訳値を直接取得

Development
=================

## クライアント用コード

`src`以下を編集してください。
`app/assets/*`を直接編集したらダメよ！

```
$ yarn dev   # 開発時
$ yarn build   # ビルド
```


## Spec

### default spec

```
$ bundle exec rspec
```

## release gem

    $ bundle exec rake build      # build gem to pkg/ dir
    $ bundle exec rake install    # install to local gem
    $ bundle exec rake release    # release gem to rubygems.org
