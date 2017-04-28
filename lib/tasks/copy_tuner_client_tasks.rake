namespace :copy_tuner do
  desc "Notify CopyTuner of a new deploy."
  task :deploy => :environment do
    CopyTunerClient.deploy
    puts "Successfully marked all blurbs as published."
  end

  desc "Export CopyTuner blurbs to yaml."
  task :export => :environment do
    CopyTunerClient.cache.sync

    if yml = CopyTunerClient.export
      path = "config/locales/copy_tuner.yml"
      File.new("#{Rails.root}/#{path}", 'w').write(yml)
      puts "Successfully exported blurbs to #{path}."
    else
      puts "No blurbs have been cached."
    end
  end

  desc "Check unpublished blurbs."
  task :check_unpublished_blurbs => :environment do
    puts "Checking unpublished blurbs...."
    if CopyTunerClient.has_unpublished_blurbs?
      puts "[Warning] There are unpublished blurbs!!!!!!"
    else
      puts "All blurbs published"
    end
  end
end
