require 'webdrivers'
require 'pstore'
require 'nokogiri'

class AmazonChromeDriver
  attr_reader :driver, :cache

  def rand_sleep(max_seconds=5)
    seconds = rand(2..max_seconds)
    print "sleeping for #{seconds} seconds..."
    sleep seconds
    puts "done"
  end

  def initialize
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')

    @driver = Selenium::WebDriver.for :chrome, options: options
    driver.manage.timeouts.implicit_wait = 5 # seconds

    @cache = PStore.new("cache.store", true)
  end

  def login
    driver.navigate.to "https://www.amazon.com"
    rand_sleep
    driver.find_element(:css, "#nav-signin-tooltip > a.nav-action-button").click
    rand_sleep
    driver.find_element(:id, "ap_email").clear
    driver.find_element(:id, "ap_email").send_keys("amazon@bugsplat.info")

    begin
      driver.find_element(:id, "continue").click
      rand_sleep
    rescue Selenium::WebDriver::Error::NoSuchElementError
      puts "no continue button, moving on"
    end

    driver.find_element(:id, "ap_password").clear
    driver.find_element(:id, "ap_password").send_keys("aL1304AlAn!")
    driver.find_element(:id, "signInSubmit").click()
    rand_sleep
  end

  def get_url(url)
    cache.transaction do
      cache_key = "cache::#{url}"
      expires_key = "expires::#{url}"
      
      if cache.has_key?(expires_key) && Time.stamp < cache[expires_key]
        puts "using cache for #{url}"
        return cache[cache_key]
      else
        driver.get_url(url)
        rand_sleep
        source = driver.page_source
        cache[cache_key] = source
        cache[expires_key] = Time.stamp + 30*60
        return source
      end
    end
  end

  def fetch(url)
    source = get_url(url)
    Nokokiri::HTML(source)
  end
end

if __FILE__ == $PROGRAM_NAME
  driver = AmazonChromeDriver.new
  driver.login
end
