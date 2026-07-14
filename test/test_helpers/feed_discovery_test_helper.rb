module FeedDiscoveryTestHelper
  # Replaces Feed::Discovery.call with a canned result for the block so tests
  # never reach out to the network. Pass `raises:` an exception to simulate an
  # unreachable address instead. (Minitest 6 dropped the bundled mock, so
  # there's no Object#stub to lean on here.)
  def stub_discovery(result = nil, raises: nil)
    original = Feed::Discovery.method(:call)
    Feed::Discovery.define_singleton_method(:call) do |_url|
      raise raises if raises

      result
    end
    yield
  ensure
    Feed::Discovery.define_singleton_method(:call, original)
  end
end
