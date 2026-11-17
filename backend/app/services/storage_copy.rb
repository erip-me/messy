# Moves Active Storage files from one configured service to another (e.g. disk
# to a bucket) and repoints each blob, so an upload keeps working throughout:
# a blob is only repointed once its file is in the new service. Idempotent —
# re-running picks up blobs uploaded since the last run.
class StorageCopy
  def self.call(from:, to:, log: $stdout)
    source = ActiveStorage::Blob.services.fetch(from.to_sym)
    target = ActiveStorage::Blob.services.fetch(to.to_sym)
    copied = missing = 0

    ActiveStorage::Blob.where(service_name: from.to_s).find_each do |blob|
      unless source.exist?(blob.key)
        missing += 1
        log.puts "missing on #{from}: blob #{blob.id} #{blob.key}"
        next
      end
      unless target.exist?(blob.key)
        source.open(blob.key, checksum: blob.checksum) do |file|
          target.upload(blob.key, file, checksum: blob.checksum, content_type: blob.content_type)
        end
      end
      blob.update_columns(service_name: to.to_s)
      copied += 1
    end

    log.puts "copied=#{copied} missing=#{missing}"
    { copied: copied, missing: missing }
  end
end
