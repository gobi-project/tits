namespace :delete do
  desc "Delete single series"
  task :series, [:resource_id] do |task, args|
    require 'TITS'
    TITS.delete_series args.resource_id
  end

  desc "Delete whole db"
  task :db do
    require 'TITS'
    TITS.delete_db
  end
end
