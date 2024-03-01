require "playwright"
require "set"

def fetch_year_month(page)
  year_month = page.locator("#v-ipo-top h3").first.text_content
  /(\d+)年(\d+)月/.match(year_month)[1,2].map(&:to_i)
end

# Click the previous month button
def goto_previous_year(page)
  page.locator("xpath=//*[@id='v-ipo-top']/div[2]/div/div/div[1]/div[1]/div[1]").click
end

# Click the next month button
def goto_next_year(page)
  page.locator("xpath=//*[@id='v-ipo-top']/div[2]/div/div/div[1]/div[1]/div[3]").click
end

def seek_to_past_year_month(page, year, month)
  loop do
    goto_previous_year(page)
    sleep 0.2

    y, m = fetch_year_month(page)
    break if y == year && m == month
  end
end

def obtain_urls(page)
  page.locator("#ipo-calendar-table table tr:nth-child(n+2) th a").all.map { |a| a["href"] }
end

start_url = "https://minkabu.jp/ipo"

Playwright.create(playwright_cli_executable_path: './node_modules/.bin/playwright') do |playwright|
  playwright.chromium.launch(headless: true) do |browser|
    page = browser.new_page
    page.goto(start_url)

    # Obtain the current year
    year, month = fetch_year_month(page)

    # Seek to 3 years ago
    seek_to_past_year_month(page, year - 3, 1)

    urls = Set.new
    loop do
      obtain_urls(page).each do |u|
        full_url = File.join("https://minkabu.jp", u)
        urls << full_url
      end

      y, m = fetch_year_month(page)
      $stderr.puts "%04d.%02d DONE" % [y, m]

      break if y == year && m == month

      goto_next_year(page)
      sleep 0.2
    end

    puts urls
  end
end
