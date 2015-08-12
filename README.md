[![Build
Status](https://travis-ci.org/wunderlist/reliable.svg?branch=master)](https://travis-ci.org/wunderlist/reliable)

# Reliable is.

Redis is a great storage service for building a reliable queue. That's
what this is for.

## Is this like [Ost](https://github.com/soveran/ost)?

Ost was the inspiration for this project. We love ost, but it lacks a few of the nice things we want (retry, failures count, etc) and will will implement those extra features here. We also wanted parallelism baked in.

## Configuring redis

Reliable uses `Redic`.

```ruby
require 'reliable'
Reliable.redis = Redic.new(ENV.fetch("REDIS_URL"))
```

## Enqueueing messages

The developer is responsible for enqueuing `String`s or string-like
objects.

```ruby
Reliable[:messages].push(JSON.generate({
  id: 123,
  title: "Hello"
}))
```

In this example `:messages` is the queue name. The developer can make as
many queues as they like.

## Processing messages

### Processing all messages as they arrive

```ruby
Reliable[:messages].each do |message|
  hash = JSON.generate(message)
  DatabaseTable.find(hash["id"]).do_something_awesome(message)
end
```

or

```ruby
Reliable[:emails].each do |message|
  hash = JSON.generate(message)
  Emailer.new(hash).deliver
end
```

Calling `#each` will block the main thread and sleep forever.

### Processing messages in parallel

If the processing code is thread-safe, the developer can spawn any
number of threads with `#peach`:

```ruby
Reliable[:touches].peach(concurrency: 12) { |id| Model.find(id).touch }
```

In this example 12 threads will be created and all are joined with the
main thread.

### Processing some messages

It's also possible to process only some message by `#take`-ing as many
as necessary:

```ruby
Reliable[:urls].take(2) do |url|
  content = open(url)
  PersistentStore.store(content)
end
```

And if the developer wants, they can get an enumerator object of
the processor and interact with it as necessary:

```ruby
enumerator = Reliable[:ids].processor.to_enum { |id| notify(id) }
assert_equal 0, notifications.length
4.times { enumerator.next }
assert_equal 4, notifications.length
```

# Time

Make sure the distributed clock starts moving before you lock the main thread. Here is a full example:

```ruby
Reliable[:emails].periodically_move_time_forward
Reliable[:emails].peach(concurrency: 6) do |message|
  hash = JSON.generate(message)
  Emailer.new(hash).deliver
end
```
