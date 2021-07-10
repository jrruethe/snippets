#!/usr/bin/env ruby

module Mixins
  module RateLimit

    def rate_limit(name, requests_per_sec)
      @@sliding_window = []
      method = instance_method(name)

      define_method(name) do |*args|
        now = Time.now.utc

        # Delete all entries older than 1 second
        @@sliding_window.delete_if{|t| t < now - 1}

        # If we hit the limit
        if @@sliding_window.size >= requests_per_sec
          # Wait long enough to drop below the limit
          delay = now - @@sliding_window.first
          #STDERR.puts "#{name} #{args.inspect} : Rate limit exceeded, waiting #{delay} seconds..."
          sleep delay
        end

        retval = method.bind(self).call(*args)
        @@sliding_window << Time.now.utc
        return retval
      end
    end

  end

  module Cache

    def flush_cache
      flush_positive_cache
      flush_negative_cache
    end

    def flush_positive_cache
      @@positive_cache = Hash.new{|h,k| h[k] = {}}
    end

    def flush_negative_cache
      @@negative_cache = Hash.new{|h,k| h[k] = {}}
    end

    def cache(name, duration = nil, positive_duration: duration, negative_duration: duration)
      @@positive_cache ||= Hash.new{|h,k| h[k] = {}}
      @@negative_cache ||= Hash.new{|h,k| h[k] = {}}
      method = instance_method(name)

      define_method(name) do |*args|

        # Check the positive cache
        timestamp, retval = @@positive_cache[name][args]

        if timestamp
          # Result was in the positive cache
          # Check to see if it is still relevant
          return retval if positive_duration.nil?
          return retval if Time.now.utc - timestamp < positive_duration
        end

        # Result was not in the positive cache
        # Check the negative cache
        timestamp, retval = @@negative_cache[name][args]

        if timestamp
          # Result was in the negative cache
          # Check to see if it is still relevant
          return retval if negative_duration.nil?
          return retval if Time.now.utc - timestamp < negative_duration
        end

        # If we make it here, then a recent result was not in the cache.
        # Execute the function and cache the result
        retval = method.bind(self).call(*args)

        if retval
          # Put in the positive cache
          @@positive_cache[name][args] = [Time.now.utc, retval]
        else
          # Put in the negative cache
          @@negative_cache[name][args] = [Time.now.utc, retval]
        end

        return retval
      end
    end

  end

  module Retry

    def retry_on_nil(name, number = 6, max = 5)
      method = instance_method(name)
      define_method(name) do |*args|
        number.times do |n|
          retval = method.bind(self).call(*args)
          if retval.nil?
            # Jitter
            sleep rand(100*[max, 2**n].min)/100.0
            #STDERR.puts "#{name} #{args.inspect} : Retry #{number - n}"
            next
          end
          return retval
        end
        return nil
      end
    end

    def retry_on_exception(name, exception, number = 6, max = 5)
      method = instance_method(name)
      define_method(name) do |*args|
        ex = nil
        number.times do |n|
          begin
            retval = method.bind(self).call(*args)
          rescue exception => e
            ex = e
            # Jitter
            sleep rand(100*[max, 2**n].min)/100.0
            #STDERR.puts "#{name} #{args.inspect} : Retry #{number - n}"
            next
          end
          return retval
        end
        raise ex
      end
    end

  end
end
