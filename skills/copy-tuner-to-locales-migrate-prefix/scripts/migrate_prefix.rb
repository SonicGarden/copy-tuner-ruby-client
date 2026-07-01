# frozen_string_literal: true

# copy_tuner → config/locales prefix-unit migration script (SKILL.md step 6).
#
# Run via `bin/rails runner` so that the Rails i18n load path and CopyTuner
# configuration are available:
#
#   bin/rails runner .claude/skills/copy-tuner-to-locales-migrate-prefix/scripts/migrate_prefix.rb \
#     -- --prefix date --export tmp/copy_tuner_all.yml --out config/locales/0010_date.yml
#
# What it does, in one pass:
#   (1) Place : extract the target prefix subtree from the 0000_original_*.yml
#       originals (load-order deep_merge), deep_merge the export subtree on top
#       (export wins for string blurbs), then re-apply the originals'
#       non-representable values (arrays/symbols/numbers/booleans such as the
#       `date.order` symbol array) last so a corrupted export value cannot
#       overwrite them, and write it to --out.
#   (2) Static guards : YAML round-trip, --out is on the i18n load path, every
#       leaf key matches the prefix regexp.
#   (3) Leak check : simulate the original-deletion in memory and resolve every
#       target-prefix key through a fresh I18n::Backend::Simple. A key that goes
#       missing after deletion is a migration leak.
#   (4) Gate : only when there are zero leaks, prune the prefix subtree from the
#       originals on disk. Any leak aborts with the originals untouched.
#
# 対象 locale はプロジェクトの I18n.available_locales を実行時に参照して決める（default_locale を先頭に並べる）。
# `--locales ja,en` で明示上書きできる（fixture を使った検証用。指定時は指定順を尊重する）。

require 'optparse'
require 'yaml'

# NOTE: `bin/rails runner` は Kernel#abort が投げる SystemExit を握りつぶし終了コードが 0 になる
# （実機確認済み）。中断を呼び出し側へ確実に伝えるため、abort ではなく warn + exit(1) を使う。
def die(message)
  warn message
  exit(1)
end

# ---- 引数 ----
options = {}
parser =
  OptionParser.new do |opts|
    opts.banner = 'Usage: bin/rails runner migrate_prefix.rb -- --prefix PREFIX --export PATH --out PATH [--regexp PATTERN] [--originals-glob GLOB]'
    opts.on('--prefix PREFIX', 'ドット区切りの対象 prefix（例: date / activerecord.attributes）') { |v| options[:prefix] = v }
    opts.on('--export PATH', '全件 export YAML（手順3で出力）') { |v| options[:export] = v }
    opts.on('--out PATH', '移行分の出力先（例: config/locales/0010_date.yml）') { |v| options[:out] = v }
    opts.on('--regexp PATTERN', 'leaf キー検証用の正規表現（省略時は prefix から \A<prefix>\. を生成）') { |v| options[:regexp] = v }
    opts.on('--originals-glob GLOB', 'オリジナルファイルの glob（既定: config/locales/0000_original_*.yml）') { |v| options[:originals_glob] = v }
    opts.on('--locales LIST', 'カンマ区切りの対象 locale（既定: I18n.available_locales。検証用の上書き）') { |v| options[:locales] = v }
  end
# `bin/rails runner script -- ...` の `--` 以降だけを渡したいが、runner が剥がさない環境もあるため両対応。
argv = ARGV.include?('--') ? ARGV[(ARGV.index('--') + 1)..] : ARGV
parser.parse!(argv)

die(parser.banner) unless options[:prefix] && options[:export] && options[:out]

PREFIX = options[:prefix]
prefix_keys = PREFIX.split('.')

# 対象 locale 群。--locales 指定時はその順を尊重、未指定なら default_locale を先頭にした available_locales。
LOCALES =
  if options[:locales]
    options[:locales].split(',').map(&:strip).reject(&:empty?)
  else
    ([I18n.default_locale.to_s] + I18n.available_locales.map(&:to_s)).uniq
  end
# 黙って 'ja' に倒すと将来 locale 追加時にサイレント脱落を招くため、空なら明示的に中断する。
die('対象 locale が空。I18n.available_locales が取れているか（Rails 環境のロード）、--locales の指定を確認すること。') if LOCALES.empty?
# 既定の regexp は prefix に \A アンカーを付けたもの（手順7の local_first_key_regexp と整合させる）。
regexp = options[:regexp] ? Regexp.new(options[:regexp]) : /\A#{Regexp.escape(PREFIX)}\./o
originals_glob = options.fetch(:originals_glob, 'config/locales/0000_original_*.yml')

# ---- ヘルパ ----

# ネスト Hash を非破壊 deep merge（右辺優先）。配列・スカラはそのまま右辺で置換。
def deep_merge(base, override)
  base.merge(override) do |_key, b, o|
    b.is_a?(Hash) && o.is_a?(Hash) ? deep_merge(b, o) : o
  end
end

def deep_merge!(base, override)
  base.replace(deep_merge(base, override))
end

# YAML をロードして指定 locale ルート（例 `ja:`）配下の Hash を返す。シンボル（date.order の :year 等）を許可。
def load_locale_tree(path, locale)
  raw = YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true) || {}
  raw[locale] || {}
end

# prefix（["date"] や ["activerecord","attributes"]）のサブツリーを掘り出す。無ければ nil。
def dig_prefix(tree, keys)
  keys.reduce(tree) do |node, key|
    return nil unless node.is_a?(Hash) && node.key?(key)

    node[key]
  end
end

# prefix サブツリーを {"date" => {...}} のように prefix で包んだ Hash にして返す（無ければ {}）。
def extract_prefix(tree, keys)
  sub = dig_prefix(tree, keys)
  return {} if sub.nil?

  keys.reverse.reduce(sub) { |acc, key| { key => acc } }
end

# prefix サブツリーを取り除いた新しい Hash を返す。空になった親も刈る（非破壊）。
def prune_prefix(tree, keys)
  head, *rest = keys
  return tree unless tree.is_a?(Hash) && tree.key?(head)

  dup = tree.dup
  if rest.empty?
    dup.delete(head)
  else
    pruned_child = prune_prefix(dup[head], rest)
    if pruned_child.is_a?(Hash) && pruned_child.empty?
      dup.delete(head) # 空親を刈る
    else
      dup[head] = pruned_child
    end
  end
  dup
end

# ネスト Hash の全 leaf を「ドット区切りキー => 値」で返す。配列・シンボル・nil 値は leaf として扱い、
# その中までは展開しない（date.order の [:year,...] は date.order 1 個）。
def leaf_entries(tree, prefix = [])
  tree.each_with_object({}) do |(key, value), acc|
    path = prefix + [key]
    if value.is_a?(Hash) && !value.empty?
      acc.merge!(leaf_entries(value, path))
    else
      acc[path.join('.')] = value
    end
  end
end

# ネスト Hash から「非表現値（非 String・非 Hash の leaf）だけ」を残したネスト Hash を返す。
# 配列・シンボル・数値・真偽値・nil が対象。String leaf は捨てる（export 勝ちに委ねる）。
# copy_tuner は flat な文字列 blurb しか持てず、これらは export に出てこない／壊れて出る可能性がある。
# orig 由来のこの結果を最後に deep_merge することで、壊れた export 値が非表現値を上書きするのを防ぐ。
def select_non_blurb(tree)
  tree.each_with_object({}) do |(key, value), acc|
    if value.is_a?(Hash) && !value.empty?
      child = select_non_blurb(value)
      acc[key] = child unless child.empty? # 非表現値が残った枝だけ保持
    elsif !value.is_a?(String) && !value.is_a?(Hash)
      acc[key] = value # Array / Symbol / Integer / Float / true / false / nil
    end
  end
end

# locale ルートを持つ raw Hash（`{ "ja" => {...}, "en" => {...} }`）から、対象 prefix を全 locale で刈った
# 新しい Hash を返す（非破壊）。移行漏れ検証のシミュレーションと実削除の両方で使う。
def prune_prefix_all_locales(raw, locales, keys)
  locales.reduce(raw) { |acc, locale| acc.merge(locale => prune_prefix(acc[locale] || {}, keys)) }
end

# ---- (1) 配置 ----
out_path = options[:out]
# Dir.glob は Ruby 3.0+ で昇順ソート済み（= Rails の i18n ロード順と同じ）を返す。
original_files = Dir.glob(originals_glob)
die("オリジナルが見つからない: #{originals_glob}") if original_files.empty?

# locale ごとに merged サブツリーを構築する。{ "ja" => {...}, "en" => {...} } の形。
# あるロケールに当該 prefix のキーが一つも無い（orig も export も空）場合は warn してスキップし、
# 書き出し・検証から自然に除外する（複数ロケールでは「en は別 prefix しか持たない」等が正常に起こりうる）。
merged_by_locale = {}
LOCALES.each do |locale|
  orig_sub = {}
  original_files.each { |f| deep_merge!(orig_sub, extract_prefix(load_locale_tree(f, locale), prefix_keys)) }

  exp_sub = extract_prefix(load_locale_tree(options[:export], locale), prefix_keys)

  if orig_sub.empty? && exp_sub.empty?
    warn("locale #{locale}: prefix '#{PREFIX}' のキーが無いためスキップ")
    next
  end

  # orig がベース・export で上書き（String leaf は export 勝ち）し、最後に非表現値（非 String leaf）を
  # orig 値で再適用して必ず勝たせる。export 側に壊れた非表現値（文字列化等）が出ても置換されない。
  merged_by_locale[locale] = deep_merge(deep_merge(orig_sub, exp_sub), select_non_blurb(orig_sub))
end

# 全 locale でスキップ＝当該 prefix がどこにも存在しない（prefix の typo）。
die("prefix '#{PREFIX}' のキーが export にもオリジナルにも見つからない。prefix を確認すること。") if merged_by_locale.empty?

# ---- (2) 静的ガード（書き出し前にできる検証を先に。中途半端な --out を残さない）----
# --out が次回起動時に Rails の i18n glob でロードされる場所か（採番ミス・配置ミスの検出）。
# NOTE: I18n.load_path は runner 起動時に確定済みで、いま書き出す --out は含まれない。よって
# 「現在の load_path に在るか」ではなく「Rails 標準 glob（config/locales/**/*.yml）に合致するか」を確認する。
abs_out = File.expand_path(out_path)
locales_root = File.expand_path('config/locales')
unless abs_out.start_with?("#{locales_root}/") && abs_out.end_with?('.yml', '.yaml')
  die("#{out_path} が config/locales 配下の .yml ではない。Rails の i18n ロード対象になる場所へ出力すること。")
end

# 全 leaf キーが regexp にマッチするか（regexp と prefix の不一致の早期検出）。leaf キーは locale を
# 含まない（merged は locale ルート配下）ので、全 locale を同じ regexp で検証できる。
merged_by_locale.each do |locale, merged|
  non_matching = leaf_entries(merged).keys.grep_v(regexp)
  next if non_matching.empty?

  die("locale #{locale}: regexp #{regexp.inspect} にマッチしない leaf キーがある（regexp/prefix 不一致）:\n  #{non_matching.join("\n  ")}")
end

# 書き出し（ここまでの検証を通過してから）。merged_by_locale は { "ja" => {...}, "en" => {...} } 形なので
# そのまま全 locale ルートを持つ YAML になる（スキップした locale は含まれない）。
File.write(out_path, merged_by_locale.to_yaml)
total_leaves = merged_by_locale.sum { |_locale, merged| leaf_entries(merged).size }
puts "配置: #{out_path} （locale #{merged_by_locale.keys.join(',')} / leaf 合計 #{total_leaves} キー）"

# YAML ラウンドトリップ（to_yaml → 再読込で各 locale の merged と一致するか）。
merged_by_locale.each do |locale, merged|
  die("YAML ラウンドトリップ不一致。書き出し結果が壊れている: #{out_path} (locale #{locale})") unless load_locale_tree(out_path, locale) == merged
end

# ---- (3) 移行漏れ検証（削除をメモリ上でシミュレート）----
# 削除後に Rails がロードするであろう全 locales ツリーを実ロード順で再現する。
#
# NOTE: いま書き出した --out は起動時確定の I18n.load_path に含まれない（実機確認済み）。そのため
# load_path 由来の既存ファイル群（gem の locale 含む）を実順で読みつつ、--out を**末尾に明示追加**して
# 後勝ちさせ、「削除後＋移行分ロード済み」の状態を再現する。
abs_out = File.expand_path(out_path)
sim_paths = I18n.load_path.dup
sim_paths << out_path unless sim_paths.map { |p| File.expand_path(p) }.include?(abs_out)
original_abs = original_files.map { |f| File.expand_path(f) }

sim_tree = {}
sim_paths.each do |path|
  next unless File.exist?(path)
  next unless path.end_with?('.yml', '.yaml') # .rb ロードパスはこのスキルの範囲外（必要なら別途）

  content = YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true) || {}
  next unless content.is_a?(Hash)

  # オリジナルからは対象 prefix を全 locale で刈った状態にする（実削除後と等価）。
  content = prune_prefix_all_locales(content, LOCALES, prefix_keys) if original_abs.include?(File.expand_path(path))
  deep_merge!(sim_tree, content)
end

sim = I18n::Backend::Simple.new
sim_tree.each { |loc, data| sim.store_translations(loc, data) }

# NOTE: missing 判定は `default:` センチネルで行う。`throw: true` は missing 時に Ruby の throw
# （catch/throw フロー制御）で MissingTranslation を投げるため rescue では捕まらず UncaughtThrowError に
# なる（実機確認済み）。default にユニークなオブジェクトを渡せば、missing のときだけそれが返る。
# 空文字 "" は「存在」扱い（センチネルと equal? でないため missing 扱いしない）。
missing = Object.new

# 母集合は locale ごとに独立に取る（= その locale の merged の全 leaf キー）。locale 横断の和集合に
# すると、en にしか無いキーを ja で lookup して誤検知する。各 locale はその locale に実在するキーだけ検証する。
leaks = []
merged_by_locale.each do |locale, merged|
  leaf_entries(merged).each_key do |key|
    value = sim.translate(locale.to_sym, key, default: missing)
    leaks << [locale, key] if value.equal?(missing)
  end
end

# ---- (4) ゲート ----
unless leaks.empty?
  warn "移行漏れ検出: 削除すると次の #{leaks.size} キーが未訳になる。オリジナルは変更していない。"
  leaks.sort.each { |locale, key| warn "  - #{locale}: #{key}" }
  die('中断。--out の内容・採番・regexp を確認すること。')
end

original_files.each do |f|
  raw = YAML.safe_load_file(f, permitted_classes: [Symbol], aliases: true) || {}
  File.write(f, prune_prefix_all_locales(raw, LOCALES, prefix_keys).to_yaml)
end

puts "削除: prefix '#{PREFIX}' をオリジナル #{original_files.size} ファイルから刈り取った。"
puts '完了。手順7（local_first_key_regexp 追加）が未済なら次に実施すること。'
