module FeedDiscoveryTestHelper
  # Replaces Feed::Discovery.call with a canned result for the block so tests
  # never reach out to the network. (Minitest 6 dropped the bundled mock, so
  # there's no Object#stub to lean on here.)
  def stub_discovery(result)
    original = Feed::Discovery.method(:call)
    Feed::Discovery.define_singleton_method(:call) { |_url| result }
    yield
  ensure
    Feed::Discovery.define_singleton_method(:call, original)
  end
end
