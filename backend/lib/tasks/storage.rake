namespace :storage do
  desc "Copy Active Storage files between services and repoint the blobs: storage:copy[local,s3]"
  task :copy, [:from, :to] => :environment do |_, args|
    StorageCopy.call(from: args.fetch(:from), to: args.fetch(:to))
  end
end
