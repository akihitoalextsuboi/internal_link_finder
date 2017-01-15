require 'open-uri'
require 'nokogiri'
require 'logger'
require 'csv'
require 'nkf'

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
      puts page
      crawl_each(page)
    end.flatten(1)
    write_csv(results)
    results
  end

  def crawl_each(page)
    html = html(URI.encode(page))
    scheme = URI.parse(URI.encode(page)).scheme
    host = URI.parse(URI.encode(page)).host
    title = html.title
    description = html.at('meta[name=description]')['content'].chomp.strip.chomp.strip
    h1 = html.search('h1').inner_text.chomp.strip.chomp.strip
    html.search('a').map do |link|
      if link['href'] == '/'
        [page, title, description, h1, "#{scheme}://#{host}/"]
      elsif link['href']&.start_with?('/')
        [page, title, description, h1, "#{scheme}://#{host}#{link['href']}"]
      elsif link['href']&.include?(host)
        [page, title, description, h1, link['href']]
      end
    end.compact
  rescue OpenURI::HTTPError => e
    if e.message == '404 Not Found'
      [page, e.message, e.message, e.message, e.message]
    elsif e.message == '403 Forbidden'
      [page, e.message, e.message, e.message, e.message]
    else
      [page, e.message, e.message, e.message, e.message]
    end
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
    logger = Logger.new('crawler.log')
    logger.warn("Can't access #{uri}")
    logger.warn(e.message)
    raise e
  end

  def pages
    NKF.nkf('-w', File.read('./pages.txt')).each_line.map(&:chomp)
  end

  def write_csv(results)
    csv_outbound = CSV.generate do |csv|
      csv << %w(original_page title description h1 outbound_link)
      results.each do |result|
        csv << result
      end
    end
    File.write('./outbound_link.csv', NKF::nkf('--sjis -Lw', csv_outbound))

    csv_inbound = CSV.generate do |csv|
      csv << %w(page title(original_page) description(original_page) h1(original_page) inbound_link(original_page))
      results.group_by { |result| result[4] }.values.flatten(1).map do |array|
        [array[4], array[1], array[2], array[3], array[0]]
      end.each do |inbound|
        csv << inbound
      end
    end
    File.write('./inbound_link.csv', NKF::nkf('--sjis -Lw', csv_inbound))
  end
end

InternalCrawler.new.crawl
