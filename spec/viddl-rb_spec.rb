$LOAD_PATH << File.join(File.dirname(__FILE__), '..', 'lib')

require 'rubygems'
require 'minitest/autorun'
require 'viddl-rb.rb'

class TestURLExtraction < MiniTest::Unit::TestCase
  def initialize(*args)
    @video_uf    = ViddlRb.get_urls_and_filenames("http://www.youtube.com/watch?v=CFw6s0TN3hY")
    @playlist_uf = ViddlRb.get_urls_and_filenames("http://www.youtube.com/playlist?list=PLA54DEEE9255E2B1C")
    super(*args)
  end

  def test_return_array_on_valid
    assert @video_uf.is_a?(Array)
    assert @playlist_uf.is_a?(Array)
  end

  def test_returns_nil_on_invalid_url
    assert_equal nil, ViddlRb.get_urls_and_filenames("http://www.testing.rb")
  end

  def test_raises_pluginerror_on_error
    #hackish way to force an exception. "youtu.be" in the address makes an uri-open #open call which fails. 
    assert_raises(ViddlRb::PluginError) { ViddlRb.get_urls_and_filenames("///youtu.be") }
  end

  def test_single_video_size_is_one
    assert @video_uf.size == 1
  end

  def test_playlist_size_is_greater_than_one   #don't check exact size in case videos are added 
    assert @playlist_uf.size > 1
  end

  def test_hash_has_url_and_name_keys
    assert @video_uf.first.has_key?(:url)
    assert @video_uf.first.has_key?(:name)
    assert @playlist_uf.last.has_key?(:url)
    assert @playlist_uf.last.has_key?(:name)
  end

  def test_download_url_is_url
    assert @video_uf.first[:url] =~ /^http:\/\//
    assert @playlist_uf.last[:url] =~ /^http:\/\//
  end

  def test_name_is_correct    #don't check exact names in case the naming scheme changes
    assert @video_uf.first[:name] =~ /harddrive/i
    assert @playlist_uf.first[:name] =~ /20110525/
  end
end
