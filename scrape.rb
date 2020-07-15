require 'webdrivers'
require 'pstore'
require 'nokogiri'

class AmazonChromeDriver
  attr_reader :driver, :cache

  ORDER_DATE_RE = /Order Placed:/
  ORDER_ID_RE = /orderID=([0-9-]+)/
  BASE_URL = "https://www.amazon.com"

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
    driver.navigate.to BASE_URL
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
      
      if cache[expires_key] && Time.now < cache[expires_key]
        puts "using cache for #{url}"
        return cache[cache_key]
      else
        driver.navigate.to(url)
        rand_sleep
        source = driver.page_source
        cache[cache_key] = source
        cache[expires_key] = Time.now + 30*60
        return source
      end
    end
  end

  def fetch(url)
    source = get_url(url)
    Nokogiri::HTML(source)
  end

  def order_nums(year)
    order_nums = Set.new({})
    url = start_url(year)
    
    page_num = 2
    loop do
      html = fetch(url)
      order_nums += html.css('a[href]').map do |a|
        match = ORDER_ID_RE.match(a['href'])
        next unless match
        match[1]
      end.compact

      page_links = html.xpath("//a[text()='#{page_num}']")
      break if page_links.length == 0
      url = BASE_URL + page_links[0]['href']
      page_num += 1
    end

    order_nums
  end

  def start_url(year)
    "#{BASE_URL}/gp/css/history/orders/view.html?orderFilter=year-#{year}&startAtIndex=1000"
  end

  def order_url(order_id)
    "#{BASE_URL}/gp/css/summary/print.html/ref=od_aui_print_invoice?ie=UTF8&orderID=#{order_id}"
  end
end

if __FILE__ == $PROGRAM_NAME
  driver = AmazonChromeDriver.new
  driver.login

  order_nums = driver.order_nums('2020')
  order_nums.each do |oid|
    url = driver.order_url(oid)

    File.open("orders/#{oid}.html", "w+") do |f|
      f.write driver.get_url(url)
    end

    # x.xpath(%Q{//b[contains(text(), 'Credit Card transactions')]}).first.ancestors('tr').first.css('table tr').map { |tr| tr.children.map(&:text).map(&:strip) }    

    break
  end
end
