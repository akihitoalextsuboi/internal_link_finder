require 'open-uri'
require 'nokogiri'
require 'logger'
require 'csv'

class InternalCrawler
  HTTP_PROXY = ENV['HTTP_PROXY']

  def initialize(proxy: HTTP_PROXY)
    @domain = 'https://jooy.jp/'
    @user_agent = "User-Agent: Mozilla/5.0 (Windows NT 6.1; rv:28.0) Gecko/20100101 Firefox/28.0"
    @referer = @domain
    @proxy = proxy
  end

  def crawl
    results = pages.map do |page|
      crawl_each(page)
    end.flatten(1)
    write_csv(results)
  end

  def crawl_each(page)
    html = html(page)
    scheme = URI.parse(page).scheme
    host = URI.parse(page).host
    html.search('a').map do |link|
      if link['href'] == '/'
        [page, "#{scheme}://#{host}/"]
      elsif link['href'].start_with?('/')
        [page, "#{scheme}://#{host}#{link['href']}"]
      elsif link['href'].include?(host)
        [page, link['href']]
      end
    end.compact
  end

  private

  def html(uri)
    file = open(
      uri,
      "User-Agent" => @user_agent,
      "Referer" => @referer,
      :proxy => @proxy
    )
    Nokogiri::HTML(file)
  rescue OpenURI::HTTPError => e
    puts "Can't access #{uri}"
    puts e.message
    logger = Logger.new('log/crawler.log')
    logger.warn("Can't access #{uri}")
    logger.warn(e.message)
  end

  def pages
    File.readlines('./pages.txt').map(&:chomp)
  end

  def write_csv(results)
    CSV.open('./result.csv', 'w') do |csv|
      csv << %w(page internal_link)
      results.each do |result|
        csv << result
      end
    end
  end
end

InternalCrawler.new.crawl
