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
keys = []
cursor = 0
loop do
  cursor, list = redis.send "SCAN", cursor, "queue.*.process.*.agent.*.processing"
  keys << list
  break if cursor == 0
end
redis.clear
keys.flatten.compact.uniq.each do |key|
  redis.queue "LLEN", key
end
total = redis.commit.map(&:to_i).reduce(:+)
```

### Processor

A processor must generate a uuid and then start however many workers:

```ruby
class Processor
  def initialize(queue_name:, concurrency:, &work)
    @conn = Redic.new
    @uuid = SecureRandom.uuid
    @queue_name = queue_name
    @pending_key = "queue:#{queue_name}:pending"
    @workers = concurrency.times.map do
      Worker.new(process_uuid: @uuid, pending_key: @pending_key, queue_name: @queue_name, &work)
    end
  end

  def push(item)
    string = JSON.generate(item)
    uuid = SecureRandom.uuid
    @conn.send "SET", uuid, string
    @conn.send "LPUSH", @pending_key, uuid
    uuid
  end

  def stop
    @workers.map(&:stop)
  end
end

process = Processor.new(queue_name: "incoming_stuff", concurrency: 6) do |stuff|
  SendyThingy.send_to_other_thing(stuff)
end

Signal.tap("TERM") do
  process.stop
  sleep 5
end

sleep
```

### Worker

An worker must connect to redis and then try to read values over into it's list to then process them:

```ruby
class Worker
  def initialize(process_uuid:, pending_key:, queue_name:, &work)
    @uuid = SecureRandom.uuid
    @work = work
    @pending_key = pending_key
    @processing_key = "queue:#{queue_name}:process:#{process_uuid}:worker:#{@uuid}:processing"
    @thread = create_thread
    @mutex = Mutex.new
  end

  def create_thread
    Thread.new(@pending_key, @processing_key, @work) do |pending_key, processing_key, work|
      conn = Redic.new
      loop do
        @mutex.synchronize { break if @stopping }

        key = conn.send "BRPOPLPUSH", pending_key, processing_key, 2
        next if key.nil?

        item = conn.send "GET", key
        work.call(item) unless item.nil?

        conn.send "LPOP", processing_key
      end
      conn.quit
    end
  end

  def stop
    @mutex.synchronize { @stopping = true }
  end
end
```
