# frozen_string_literal: true

# copy_tuner_client v2.0.0 移行: tt → t 置換スクリプト（SKILL.md 手順 1〜2）。
#
# copy_tuner_client が生やしていた独自ヘルパー tt は PR #122 で削除された。gem を上げた
# アプリのビューに tt(...) が残ると NoMethodError になるため t へ移す。大半は機械的に
# tt( → t( で済むが、訳文を文字列加工している箇所だけは素朴に t へ変えると開発環境で
# マーカートークン混入バグが再発する（skills/copy-tuner/SKILL.md の罠を参照）。そこは
# I18n.t（絶対キー）へ変換すべきなので、このスクリプトは自動変換せず「怪しい」として抽出する。
#
# Rails context は不要なので素の ruby で動く:
#
#   ruby skills/copy-tuner-to-t-migrate/scripts/migrate_tt.rb --report
#   ruby skills/copy-tuner-to-t-migrate/scripts/migrate_tt.rb --apply-safe
#
# 出力する 3 分類:
#   (1) safe       : 文字列加工されていない tt 呼び出し。tt( → t( に決定論的変換できる。
#   (2) suspicious : 戻り値が同一行で文字列加工されている tt 呼び出し。I18n.t 提案・要確認。
#   (3) other      : app 外 / tt を含む別識別子の誤検出など。自動変換せず目視で確認。
#
# 判定はヒューリスティック（完全な AST 解析ではない）。誤判定のコストは
#   safe 誤分類（怪しいのに safe）= マーカー混入バグ再発 → 重大
#   suspicious 誤分類（安全なのに suspicious）= 人間が 1 件確認するだけ → 軽微
# なので、疑わしきは suspicious に倒す。

require 'optparse'

# NOTE: 中断を呼び出し側（Bash 手順）へ確実に伝えるため warn + exit(1) を使う。
def die(message)
  warn message
  exit(1)
end

# ---- 引数 ----
options = { mode: :report, root: '.' }
parser =
  OptionParser.new do |opts|
    opts.banner = 'Usage: ruby migrate_tt.rb [--report | --apply-safe] [--root DIR]'
    opts.on('--report', '3 分類を出力する（既定）。ファイルは変更しない') { options[:mode] = :report }
    opts.on('--apply-safe', 'safe 分類のみ tt( → t( を実ファイルに適用する') { options[:mode] = :apply_safe }
    opts.on('--root DIR', 'リポジトリルート（既定: カレントディレクトリ）') { |v| options[:root] = v }
    opts.on('--json', 'report を JSON で出力する（機械処理用）') { options[:json] = true }
    opts.on('-h', '--help', 'ヘルプ') do
      puts opts
      exit(0)
    end
  end
parser.parse!(ARGV)

ROOT = File.expand_path(options[:root])
die("ルートが見つからない: #{ROOT}") unless File.directory?(ROOT)

# 対象: app 配下の .rb / .haml / .erb。それ以外のヒットは other 扱いで提示のみ。
APP_GLOB = File.join(ROOT, 'app', '**', '*.{rb,haml,erb}')
# app 外も走査して other に入れる（lib/ 等の取りこぼし提示用）。
ALL_GLOB = File.join(ROOT, '**', '*.{rb,haml,erb}')

# 単語境界の tt 呼び出し。tt( だけでなく haml の `= tt '...'`（括弧なし）も拾う。
# 直前が識別子文字（attr/http/setting 等の一部や `.tt` のメソッド呼び出し）でないことを (?<![\w.]) で担保。
TT_CALL = /(?<![\w.])tt(\s*\(|\s+['":@])/

# tt の「定義」側（呼び出しではない）。アプリが後方互換で `def tt` を生やしている場合がある。
# これを safe として t( へ機械置換すると Rails の t を再定義してしまい破滅的なので、定義は別扱いにする。
TT_DEFINITION = /\b(?:def\s+(?:self\.)?tt\b|alias(?:_method)?\s+:?tt\b|alias(?:_method)?\s+['"]tt['"])/

# tt(...) の戻り値が同一行で文字列加工されているかの判定に使う語彙。
STRING_HELPERS = %w[truncate simple_format strip_tags highlight excerpt word_wrap].freeze
STRING_METHODS = %w[
  length size bytesize slice first last truncate truncate_words
  gsub sub gsub! sub! strip lstrip rstrip chomp chop chars bytes lines
  scan match match? =~ start_with? end_with? include? index rindex
  upcase downcase capitalize ljust rjust center delete squeeze tr
  to_i to_f to_sym html_safe
].freeze

# (a) truncate( ... tt( ... ) のように文字列加工ヘルパーの引数になっている
STRING_HELPER_RE = /\b(?:#{STRING_HELPERS.join('|')})\s*\(\s*[^)]*\btt\b/
# (b) tt(...) または tt '...' の直後に .method / =~ / [ が続く。引数の閉じ括弧をまたぐ単純近似。
STRING_METHOD_RE = /\btt\b\s*(?:\([^\n]*?\)|['":@][^\n,]*)\s*(?:\.\s*(?:#{STRING_METHODS.join('|')})\b|=~|\[)/

# 先頭ドットの相対キー tt('.foo') は I18n.t では解決できず絶対キー化が要る → 強調表示用。
RELATIVE_KEY_RE = /\btt\b\s*(?:\(\s*)?['":]\s*\./

def relative(path)
  path.sub("#{ROOT}/", '')
end

safe = []
suspicious = []
other = []

app_set = Dir.glob(APP_GLOB).to_set

# 1 ファイル分を走査し、ヒット行を safe / suspicious / other へ振り分ける。
def scan_file(path, in_app:)
  rel = relative(path)
  File.readlines(path).each_with_index do |line, idx|
    next unless line =~ TT_CALL

    entry = { file: rel, lineno: idx + 1, code: line.rstrip }
    yield(classify_line(line, entry, in_app: in_app))
  end
rescue StandardError
  nil
end

# ヒット 1 行を分類し、[:safe | :suspicious | :other, entry] を返す。
def classify_line(line, entry, in_app:)
  # tt の定義（def/alias）は呼び出しではない。t( へ置換すると Rails の t を壊すので絶対に自動変換しない。
  if line.match?(TT_DEFINITION)
    entry[:reason] = 'tt の定義（def/alias）。自動変換禁止。呼び出しを全て t へ移した後に手動で削除する'
    return [:other, entry]
  end

  unless in_app
    entry[:reason] = 'app 外（要目視）'
    return [:other, entry]
  end

  return [:safe, entry] unless line.match?(STRING_HELPER_RE) || line.match?(STRING_METHOD_RE)

  entry[:relative_key] = line.match?(RELATIVE_KEY_RE)
  entry[:hint] = if entry[:relative_key]
                   'I18n.t へ。相対キー(.foo)は絶対キーへ書き換えが必要'
                 else
                   'I18n.t(絶対キー) へ置換を検討'
                 end
  [:suspicious, entry]
end

buckets = { safe: safe, suspicious: suspicious, other: other }
Dir.glob(ALL_GLOB).each do |path|
  # vendor / node_modules / tmp 等のノイズを除外
  next if relative(path).start_with?('vendor/', 'node_modules/', 'tmp/', '.git/')

  scan_file(path, in_app: app_set.include?(path)) do |bucket, entry|
    buckets[bucket] << entry
  end
end

if options[:json]
  require 'json'
  puts JSON.pretty_generate(safe: safe, suspicious: suspicious, other: other)
  exit(0)
end

def print_section(title, entries)
  puts "\n== #{title} (#{entries.size}) =="
  entries.each do |e|
    suffix = if e[:hint]
               "  # #{e[:hint]}"
             else
               (e[:reason] ? "  # #{e[:reason]}" : '')
             end
    puts "#{e[:file]}:#{e[:lineno]}: #{e[:code].strip}#{suffix}"
  end
end

if options[:mode] == :report
  print_section('safe（tt( → t( に決定論的変換できる）', safe)
  print_section('suspicious（文字列加工あり・I18n.t 提案・要 1 件ずつ確認）', suspicious)
  print_section('other（app 外・誤検出・要目視）', other)
  puts "\n合計: safe=#{safe.size} suspicious=#{suspicious.size} other=#{other.size}"
  exit(0)
end

# ---- --apply-safe: safe 分類のみ tt( → t( を適用 ----
# 同一ファイル内の safe 行だけを対象に、単語境界の tt を t へ置換する。
# suspicious / other 行は触らない（行番号で限定）。
by_file = safe.group_by { |e| e[:file] }
changed = 0
by_file.each do |rel, entries|
  path = File.join(ROOT, rel)
  lines = File.readlines(path)
  target_linenos = entries.to_set { |e| e[:lineno] }
  target_linenos.each do |lineno|
    line = lines[lineno - 1]
    # safe 行内の tt 呼び出しのみ t へ。tt('...') や tt(... の tt を t に。
    new_line = line.gsub(TT_CALL) { "t#{Regexp.last_match(1)}" }
    if new_line != line
      lines[lineno - 1] = new_line
      changed += 1
    end
  end
  File.write(path, lines.join)
end

puts "safe 置換を適用: #{changed} 箇所 / #{by_file.size} ファイル"
puts "残った suspicious=#{suspicious.size} other=#{other.size} は手作業で対応すること（--report で再確認）"
