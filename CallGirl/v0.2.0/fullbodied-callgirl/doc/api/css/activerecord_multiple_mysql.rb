
Connect to Multiple MySQL Servers

def self.use_table_for_app aid
  config = get_connection_config aid
  ActiveRecord::Base.establish_connection config
end

This works, but it creates a new connection on every call. Let’s suppose, we’re processing a queue and we’re handling events from different apps (customers). The cost of setting up a connection can easily outweigh the actual work. We need to cache that somehow.

Now, ActiveRecord::Base has a method called connection_config that returns, well, configuration of current connection. We can compare that to what we have on hands and, if they match, do not reconnect. Here’s how our code looks like now:

def self.use_table_for_app aid
  config = get_connection_config aid

  unless can_use_connection?(config) && ActiveRecord::Base.connection.active?
    ActiveRecord::Base.establish_connection config
  end
end

def can_use_connection? config
  current_config = ActiveRecord::Base.connection_config

  # current config can have more keys than our config (or vice versa), so simple hash comparison doesn't work.
  config.each do |k, v|
    # if even a single parameter is different - can't reuse this connection.
    if config[k] != current_config[k]
      # TODO: log warning
      return false
    end
  end
  true
end

Looks almost good. Now let’s extract this to a module for ease of re-using. Here’s the final code.

module SqlModelHelpers
  def self.included klass
    klass.send :extend, ClassMethods
  end

  module ClassMethods
    def setup_connection aid
      # TODO: do not reestablish good connections.
      # 1. get config to connect
      # 2. compare with current config (ActiveRecord::Base.connection_config)
      # 3. if configs match and connection is open - do not establish_connection
      config = get_connection_config aid

      unless can_use_connection?(config) && ActiveRecord::Base.connection.active?
        ActiveRecord::Base.establish_connection config
      end
    end

    def can_use_connection? config
      current_config = ActiveRecord::Base.connection_config

      config.each do |k, v|
        if config[k] != current_config[k]
          # TODO: log warning
          return false
        end
      end
      true
    end
  end
end

class MyModel < ActiveRecord::Base
  include SqlModelHelpers

  def self.use_table_for_app aid
    setup_connection aid

    table_name
  end
end
