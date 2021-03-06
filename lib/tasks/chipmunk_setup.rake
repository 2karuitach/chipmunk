require "fileutils"

namespace :chipmunk do
  def create_paths(app_storage_path,app_upload_user_path,user_upload_path)
    # create rsync point
    FileUtils.mkdir_p(app_storage_path) if !File.exists?(app_storage_path)
    FileUtils.mkdir_p(app_upload_user_path) if !File.exists?(app_upload_user_path)
    FileUtils.symlink(app_upload_user_path,user_upload_path) if !File.exists?(user_upload_path)
  end

  def update_config(upload_config_path,app_storage_path,app_upload_path,user_upload_path)
    # update upload.yml
    upload_config = YAML.load_file(upload_config_path)
    upload_config[Rails.env]["rsync_point"] = "localhost:#{user_upload_path}"
    upload_config[Rails.env]["storage_path"] = app_storage_path
    upload_config[Rails.env]["upload_path"] = app_upload_path
    YAML.dump(upload_config,File.new(upload_config_path,"w"))
    puts "Storage locations for #{Rails.env}:"
    puts YAML.dump(upload_config[Rails.env])
    puts
  end

  def print_user_api_key(username)
    # find/create user
    user = User.find_by_username(username)
    if !user
      user = User.create(username: username, email: "nobody@nowhere")
      user.save
    end
    puts "User API key for #{user.username}"
    puts "  export CHIPMUNK_API_KEY=#{user.api_key}"
    puts
  end

  task setup: :environment do

    username = ENV["USER"]
    app_storage_path = "#{Rails.root}/repo/storage"
    app_upload_path = "#{Rails.root}/repo/incoming"
    user_upload_path = "#{Rails.root}/incoming"
    upload_config_path = "#{Rails.root}/config/upload.yml"

    create_paths(app_storage_path,"#{app_upload_path}/#{username}",user_upload_path)
    update_config(upload_config_path,app_storage_path,app_upload_path,user_upload_path)
    puts "Ensure #{username} can rsync via ssh with write access to:"
    puts "  localhost:#{user_upload_path}"
    puts

    print_user_api_key(username)

  end
end
