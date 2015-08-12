# How to be fast

The current implementation of reliable uses too many operations that are O(n). As long as the system doesn't backup things are fast, but when things backup they will slow down a great deal: even pushing new items in. To be fast we must only use operations that are O(1) which basically means we only ever read/write to the head and tail of a list or straight to a key. No other operation can be allowed.

## Blocking

Each thread will need it's own connection so each thread can block on a list waiting for work.

The key structure will be:

```
queue:#{name}:pending
queue:#{name}:processor:#{uuid}:worker:#{uuid}:processing
queue:#{name}:failed
queue:#{name}:processed:count
queue:#{name}:failed:count
```

Knowing how many items are being processed would look like this pseudo code:

```ruby
redis = Redis.new

keys = redis.scan "queue.*.process.*.agent.*.processing"

lengths = redis.pipeline do |pipe|
  keys.each do |key|
    pipe.queue "LLEN", key
  end
end

total = lengths.map(&:to_i).reduce(:+)
```

### Processor

A processor must generate a uuid and then start however many workers:

```ruby
class Processor
  def initialize(queue_name:, concurrency:, &work)
    @redis = Redis.new
    @uuid = SecureRandom.uuid
    @queue_name = queue_name
    @pending_key = "queue:#{queue_name}:pending"
    @failed_key = "queue:#{name}:failed"
    @workers = concurrency.times.map do
      Worker.new(process_uuid: @uuid, pending_key: @pending_key, failed_key: @failed_key, queue_name: @queue_name, &work)
    end
  end

  def push(item)
    string = JSON.generate(item)
    uuid = SecureRandom.uuid
    @redis.set_and_lpush @pending_key, uuid, string
    uuid
  end

  def stop
    @workers.map(&:stop)
  end
end

processor = Processor.new(queue_name: "incoming_stuff", concurrency: 6) do |stuff|
  SendyThingy.send_to_other_thing(stuff)
end

Signal.tap("TERM") do
  processor.stop
  sleep 5
end

sleep
```

### Worker

An worker must connect to redis and then try to read values over into it's list to then process them:

```ruby
class Worker
  def initialize(process_uuid:, pending_key:, failed_key:, queue_name:, &work)
    @uuid = SecureRandom.uuid
    @work = work
    @pending_key = pending_key
    @failed_key = failed_key
    @processing_key = "queue:#{queue_name}:process:#{process_uuid}:worker:#{@uuid}:processing"
    @thread = create_thread
    @mutex = Mutex.new
  end

  def create_thread
    Thread.new(@pending_key, @processing_key, @failed_key, @work) do |pending_key, processing_key, failed_key, work|
      redis = Redis.new
      loop do
        @mutex.synchronize { break if @stopping }

        key = redis.brpoplpush pending_key, processing_key, 2
        next if key.nil?

        item = redis.get key
        if item.nil?
          redis.lpop processing_key
        else
          begin
            work.call(item)
            redis.lpop processing_key
          rescue RedisOrNetworkError
            begin
              redis.brpoplpush processing_key, failed_key, 2
            rescue
              log_error!(processing_key)
            end
          end
        end
      end
      conn.quit
    end
  end

  def stop
    @mutex.synchronize { @stopping = true }
  end
end
```
