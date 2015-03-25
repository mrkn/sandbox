require 'bundler/setup'
require 'json'

Bundler.require

Capybara.run_server = false
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app)
end

url = ARGV[0]
session = Capybara::Session.new(:poltergeist)
entries = []

while url
  puts url
  session.visit(url)

  session.within('#zg_left_colleft') do
    session.all('div.zg_itemRow').each do |item|
      image_url = item.find('.zg_image img')['src']
      rank      = item.find('.zg_rankNumber').text.to_i
      title     = item.find('.zg_title').text.strip
      by        = item.find('.zg_byline').text.strip
      platform  = item.find('.zg_bindingPlatform').text.strip
      price     = item.find('.zg_itemPriceBlock_normal .priceBlock:first-child .price').text.strip

      entries << {
        rank: rank,
        title: title,
        by: by,
        platform: platform,
        price: price,
        image_url: image_url,
      }
    end
  end

  session.within('#zg_paginationWrapper') do
    next_page_link = session.find('li.zg_page.zg_selected + li.zg_page a') rescue nil
    url = next_page_link && next_page_link['href']
  end
end

puts JSON.pretty_generate(entries)
