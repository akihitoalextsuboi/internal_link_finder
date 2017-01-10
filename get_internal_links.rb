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
      sleep 0.1
      crawl_each(page)
    end.flatten(1)
    write_csv(results)
    results
  end

  def crawl_each(page)
    html = html(page)
    scheme = URI.parse(page).scheme
    host = URI.parse(page).host
    title = html.title
    description = html.at('meta[name=description]')['content'].chomp.strip.chomp.strip
    h1 = html.search('h1').inner_text.chomp.strip.chomp.strip
    html.search('a').map do |link|
      if link['href'] == '/'
        [page, title, description, h1, "#{scheme}://#{host}/"]
      elsif link['href'].start_with?('/')
        [page, title, description, h1, "#{scheme}://#{host}#{link['href']}"]
      elsif link['href'].include?(host)
        [page, title, description, h1, link['href']]
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
    CSV.open('./outbound_link.csv', 'w') do |csv|
      csv << %w(original_page title description h1 outbound_link)
      results.each do |result|
        csv << result
      end
    end

    CSV.open('./inbound_link.csv', 'w') do |csv|
      csv << %w(page title(original_page) description(original_page) h1(original_page) inbound_link(original_page))
      results.group_by { |result| result[4] }.values.flatten(1).map do |array|
        [array[4], array[1], array[2], array[3], array[0]]
      end.each do |inbound|
        csv << inbound
      end
    end
  end
end

InternalCrawler.new.crawl
