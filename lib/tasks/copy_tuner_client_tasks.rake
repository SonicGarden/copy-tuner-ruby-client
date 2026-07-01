namespace :copy_tuner do
  desc 'Notify CopyTuner of a new deploy.'
  task deploy: :environment do
    CopyTunerClient.deploy
    puts 'Successfully marked all blurbs as published.'
  end

  desc 'Export CopyTuner blurbs to yaml.'
  task :export, %i[path] => :environment do |_, args|
    args.with_defaults(path: 'config/locales/copy_tuner.yml')
    CopyTunerClient.cache.sync

    yml = CopyTunerClient.export or raise 'No blurbs have been cached.'

    File.new("#{Rails.root}/#{args[:path]}", 'w').write(yml)
    puts "Successfully exported blurbs to #{args[:path]}."
  end

  desc 'Detect invalid keys.'
  task detect_conflict_keys: :environment do
    conflict_keys = CopyTunerClient::DottedHash.conflict_keys(CopyTunerClient.cache.blurbs)

    if conflict_keys.empty?
      puts 'All success'
    else
      puts conflict_keys.sort.join("\n")
      exit 1
    end
  end

  desc 'Detect html incompatible keys.'
  task detect_html_incompatible_keys: :environment do
    require 'copy_tuner_client/i18n_compat'
    html_incompatible_blurbs = CopyTunerClient::I18nCompat.select_html_incompatible_blurbs(CopyTunerClient.cache.blurbs)

    if html_incompatible_blurbs.empty?
      puts 'All success'
    else
      puts html_incompatible_blurbs.keys.sort.join("\n")
      exit 1
    end
  end
end
