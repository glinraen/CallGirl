require 'test_helper'

describe Redis::ActiveSupport::VERSION do
  it 'returns current version' do
    Redis::ActiveSupport::VERSION.must_equal '4.1.1'
  end
end
