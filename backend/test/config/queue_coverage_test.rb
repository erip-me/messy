require "test_helper"

# Every queue an ActiveJob declares must actually be served by a worker in
# config/queue.yml. A worker whose `queues:` no longer matches a real queue still
# boots and heartbeats happily — it just never claims a job, so the only symptom in
# production is work quietly piling up in solid_queue_ready_executions.
#
# The way to get that wrong is `queues: "a,b,c"`: Solid Queue does `Array(queues)`
# and never splits on commas (solid_queue/lib/solid_queue/worker.rb, and
# QueueSelector), so the string becomes one queue literally named "a,b,c".
class QueueCoverageTest < ActiveSupport::TestCase
  CONFIG = YAML.load(ERB.new(File.read(Rails.root.join("config/queue.yml"))).result, aliases: true).freeze

  # Queues that exist without a `queue_as` declaration: Solid Queue's own recurring
  # queue is named by the scheduler, not by a job class.
  IMPLICIT_QUEUES = %w[solid_queue_recurring].freeze

  def worker_queues(env)
    CONFIG.fetch(env).fetch("workers").flat_map { |w| w.fetch("queues") }
  end

  test "no worker declares its queues as a comma-joined string" do
    CONFIG.each_key do |env|
      worker_queues(env).each do |queue|
        refute_includes queue.to_s, ",",
          "#{env}: queue #{queue.inspect} contains a comma. Solid Queue treats that as " \
          "one queue name and the worker will never claim a job. Use a YAML list instead."
      end
    end
  end

  test "every queue_as queue is served by a worker in every environment" do
    declared = Dir[Rails.root.join("app/jobs/**/*.rb")].flat_map { |f|
      File.read(f).scan(/^\s*queue_as\s+:([a-z0-9_]+)/).flatten
    }.uniq
    assert_includes declared, "default", "sanity check: expected to find queue_as declarations"

    (declared + IMPLICIT_QUEUES).each do |queue|
      CONFIG.each_key do |env|
        served = worker_queues(env).map(&:to_s)
        assert served.include?(queue) || served.include?("*"),
          "#{env}: queue #{queue.inspect} has no worker in config/queue.yml (workers serve #{served.inspect}). " \
          "Jobs on it would pile up unprocessed."
      end
    end
  end

  test "each worker's queue pool is large enough for its thread count" do
    db = YAML.load(ERB.new(File.read(Rails.root.join("config/database.yml"))).result, aliases: true)
    # Both files open with a `default: &default` anchor that is not an environment.
    envs = (CONFIG.keys & db.keys) - ["default"]
    assert_includes envs, "production"
    envs.each do |env|
      pool = db.fetch(env).fetch("queue").fetch("pool").to_i
      CONFIG.fetch(env).fetch("workers").each do |w|
        assert_operator w.fetch("threads").to_i, :<=, pool,
          "#{env}: worker #{w["queues"].inspect} has #{w["threads"]} threads but the queue pool is #{pool}. " \
          "Solid Queue refuses to boot when a worker's pool is smaller than its thread count."
      end
    end
  end
end
