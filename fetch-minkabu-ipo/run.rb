require "axlsx"
require "bigdecimal/util"
require "playwright"
require "set"
require "time"

# TODO:
# - [ ] Check pre-IPO stock

Stock = Struct.new(
  :code,
  :market,
  :name,
  :industry,
  :ipo_date,
  :ipo_price,
  :initial_price,
  :price,
  :per,
  :pbr,
  :dividend_yields,
  :n_total_share,
  :settlement_history
) do
  def top_url
    "https://minkabu.jp/stock/#{self.code}"
  end

  def ipo_url
    "https://minkabu.jp/stock/#{self.code}/ipo"
  end

  def settlement_url
    "https://minkabu.jp/stock/#{self.code}/settlement"
  end

  def yahoo_finance_url
    "https://finance.yahoo.co.jp/quote/#{self.code}"
  end

  def fetch_stock_info!(page)
    return if fetch_cache

    # Top ページ
    page.goto(self.top_url)

    # 市場
    self.market = page.locator(%Q[xpath=//*[@id="stock_header_contents"]/div[1]/div/div[1]/div/div/div[1]/div[1]/div[1]]).text_content.strip.split(/\p{Space}+/, 2)[1]
    # 銘柄名
    self.name = page.locator(%Q[xpath=//*[@id="stock_header_contents"]/div[1]/div/div[1]/div/div/div[1]/div[1]/h1/a/p]).text_content.strip
    # 株価
    self.price = page.locator(%Q[xpath=//*[@id="stock_header_contents"]/div[1]/div/div[1]/div/div/div[1]/div[2]/div/div[2]/div]).text_content
    self.price = convert_number(self.price)
    # PER (調整後)
    self.per = page.locator(%Q[xpath=//*[@id="sh_field_body"]/div/div/div/div/div[2]/div/div[2]/div[1]/div[2]/div[1]/div[2]/table/tbody/tr[2]/td]).text_content
    self.per = convert_number(self.per)
    # PBR
    self.pbr = page.locator(%Q[xpath=//*[@id="sh_field_body"]/div/div/div/div/div[2]/div/div[2]/div[1]/div[2]/div[1]/div[2]/table/tbody/tr[4]/td]).text_content
    self.pbr = convert_number(self.pbr)
    # 配当利回り
    self.dividend_yields = page.locator(%Q[xpath=//*[@id="sh_field_body"]/div/div/div/div/div[2]/div/div[2]/div[1]/div[2]/div[1]/div[1]/table/tbody/tr[4]/td]).text_content
    self.dividend_yields = convert_number(self.dividend_yields)
    self.dividend_yields &&= self.dividend_yields / 100
    # 発行済株数
    self.n_total_share = page.locator(%Q[xpath=//*[@id="sh_field_body"]/div/div/div/div/div[2]/div/div[2]/div[1]/div[2]/div[2]/table/tbody/tr[3]/td]).text_content
    self.n_total_share = convert_number(self.n_total_share)
    self.n_total_share &&= self.n_total_share * 1000

    # IPO ページ
    random_sleep
    page.goto(self.ipo_url)

    # 上場日
    self.ipo_date = page.locator(%Q[xpath=//*[@id="contents"]/div[3]/div[3]/div[1]/dl/dd[6]]).text_content
    # 業種
    self.industry = page.locator(%Q[xpath=//*[@id="contents"]/div[3]/div[3]/div[1]/dl/dd[4]]).text_content
    # 公開価格
    self.ipo_price = page.locator(%Q[xpath=//*[@id="contents"]/div[3]/div[3]/div[2]/dl[1]/dd[3]]).text_content
    self.ipo_price = convert_number(self.ipo_price)
    # 初値
    self.initial_price = page.locator(%Q[xpath=//*[@id="contents"]/div[3]/div[3]/div[2]/dl[1]/dd[1]]).text_content
    self.initial_price = convert_number(self.initial_price)

    # 決算情報ページ
    random_sleep
    page.goto(self.settlement_url)

    # 決算情報
    rows = page.locator(%Q[xpath=//*[@id="xcompany_info"]/div[2]/div[2]/div/div[3]/div/table]).locator("tbody tr").all
    self.settlement_history = rows.map {|row|
      term_date = row.locator("th").text_content
      term = term_date[/\d+年\s*\d+月期/]
      publish_date = term_date[%r|\(\d+/\d+/\d+\)|]
      publish_date &&= Time.strptime(publish_date, "(%Y/%m/%d)")
      net_sales, operation_income, ordinal_income, net_income, eps = row.locator("td").all[-5..-1].map { convert_number(_1.text_content) }
      [ term,
        { term:,
          publish_date:,
          net_sales:,
          operation_income:,
          ordinal_income:,
          net_income:,
          eps:,
        }
      ]
    }.to_h

    # 財務情報
    rows = page.locator(%Q[xpath=//*[@id="xcompany_info"]/div[2]/div[2]/div/div[4]/div/table]).locator("tbody tr").all
    rows.each do |row|
      term = row.locator("th").text_content
      bps, = row.locator("td").all[-4..-1].map {|x| x.text_content.tr(",", "").to_d }
      (self.settlement_history[term] ||= {}).update(
        bps:
      )
    end

    store_cache
  end

  private

  def convert_number(text)
    if text.match?(/\d/)
      text.tr(",", "").to_d
    else
      nil
    end
  end

  def store_cache
    FileUtils.mkpath(cache_dir)
    dump_data = members.map {|m| [m, self[m]] }.to_h
    json = JSON.dump(dump_data)
    open(cache_path, "w") {|io| io.write(json) }
    self
  end

  def fetch_cache
    return false unless File.file?(cache_path)
    cached_data = JSON.parse(File.read(cache_path), symbolize_names: true)
    members.each {|m| self[m] = cached_data[m] }
    true
  end

  def cache_path
    @cache_path ||= File.join(cache_dir, "#{self.code}.json")
  end

  def cache_dir
    File.join(cache_home, "fetch-minkabu-ipo")
  end

  def cache_home
    ENV.fetch("XDG_CACHE_HOME", File.expand_path("~/.cache"))
  end
end

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
    random_sleep

    y, m = fetch_year_month(page)
    break if y == year && m == month
  end
end

def obtain_urls(page)
  page.locator("#ipo-calendar-table table tr:nth-child(n+2) th a").all.map { |a| a["href"] }
end

def random_sleep
  sec = rand(100 .. 1000) / 1000.0
  sleep sec
end

start_url = "https://minkabu.jp/ipo"

stocks = {}

Playwright.create(playwright_cli_executable_path: './node_modules/.bin/playwright') do |playwright|
  playwright.chromium.launch(headless: true) do |browser|
    context = browser.new_context(userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36")
    page = context.new_page

    # s = Stock.new(6861)
    # s.fetch_stock_info!(page)
    # p s
    # break

    page.goto(start_url)

    # Obtain the current year
    year, month = fetch_year_month(page)

    # Seek to 3 years ago
    begin_year = year - 3
    seek_to_past_year_month(page, begin_year, 1)

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
      random_sleep
    end

    $stderr.puts "There are #{urls.length} codes"

    Axlsx::Package.new do |xlsx|
      wb = xlsx.workbook
      s = wb.styles
      header_style = s.add_style bg_color: "EEEEEE", b: true
      int_price_style = s.add_style format_code: "¥#,##0_);[Red](¥#,##0)", alignment: {horizontal: :right}
      dec_price_style = s.add_style format_code: "¥#,##0.00_);[Red](¥#,##0.00)", alignment: {horizontal: :right}
      int_style = s.add_style num_fmt: 3, alignment: {horizontal: :right}
      dec_style = s.add_style num_fmt: 4, alignment: {horizontal: :right}
      date_style = s.add_style format_code: "yyyy/mm/dd"

      column_styles = [
        nil, # market
        nil, # Y!J
        nil, # minkabu
        nil, # code
        nil, # name
        nil, # industry
        date_style, # ipo date
        int_price_style, # ipo price
        int_price_style, # initial price
        int_price_style, # price
        dec_style, # per
        dec_style, # pbr
        dec_style, # dividend yields
        int_style, # n total share
        nil,
        dec_price_style, # net sales
        dec_price_style, # net sales
        dec_price_style, # net sales
        dec_price_style, # net sales
        nil,
        dec_price_style, # net income
        dec_price_style, # net income
        dec_price_style, # net income
        dec_price_style, # net income
        dec_price_style, # eps
        dec_price_style, # eps
        dec_price_style, # eps
        dec_price_style, # eps
        dec_price_style, # operation income
        dec_price_style, # operation income
        dec_price_style, # operation income
        dec_price_style, # operation income
        dec_price_style, # ordinal income
        dec_price_style, # ordinal income
        dec_price_style, # ordinal income
        dec_price_style, # ordinal income
        dec_price_style, # bps
        dec_price_style, # bps
        dec_price_style, # bps
        dec_price_style, # bps
      ]

      sheet_title = Time.now.strftime("%%04d〜 (%Y.%m.%d)") % begin_year
      xlsx.workbook.add_worksheet(name: sheet_title) do |sheet|
        sheet.add_row [
          "市場", #A
          "Y!J", #B
          "みん株", #C
          "コード", #D
          "銘柄", #E
          "業種", #F
          "IPO日", #G
          "公開価格", #H
          "初値", #I
          "株価", #J
          "PER", #K
          "PBR", #L
          "配当利回り", #M
          "発行済株式数", #N
          "連続増収", #O
          "売上[-3]", #P
          "売上[-2]", #Q
          "売上[-1]", #R
          "売上[-0]", #S
          "連続増益", #T
          "純利益[-3]",
          "純利益[-2]",
          "純利益[-1]",
          "純利益[-0]",
          "EPS[-3]",
          "EPS[-2]",
          "EPS[-1]",
          "EPS[-0]",
          "営業利益[-3]",
          "営業利益[-2]",
          "営業利益[-1]",
          "営業利益[-0]",
          "経常利益[-3]",
          "経常利益[-2]",
          "経常利益[-1]",
          "経常利益[-0]",
          "BPS[-3]",
          "BPS[-2]",
          "BPS[-1]",
          "BPS[-0]",
        ]

        sheet.row_style(0, header_style, widths: [:auto]*33)

        urls.each_with_index do |url, i|
          row = i + 2
          code = url[%r|stock/([\dA-Z]+)/|, 1]
          $stderr.puts "Fetching #{code} (#{i} / #{urls.length})"

          s = Stock.new(code)

          begin
            s.fetch_stock_info!(page)
          rescue Interrupt
            raise
          rescue Exception
            $stderr.puts "Skipping #{code} due to error: #{$!}"
            next
          end

          shist = s.settlement_history.values
          shist.sort_by! { _1[:term] }

          sheet.add_row [
            s.market, #A
            s.yahoo_finance_url, #B
            s.top_url, #C
            s.code, #D
            s.name, #E
            s.industry, #F
            s.ipo_date, #G
            s.ipo_price, #H
            s.initial_price, #I
            s.price, #J
            s.per, #K
            s.pbr, #L
            s.dividend_yields, #M
            s.n_total_share, #N

            %Q[=IF(AND(P#{row}<=Q#{row}, Q#{row}<=R#{row}, R#{row}<=S#{row}), "⤴️", "")], #O
            shist.dig(0, :net_sales), #P
            shist.dig(1, :net_sales), #Q
            shist.dig(2, :net_sales), #R
            shist.dig(3, :net_sales), #S

            %Q[=IF(AND(0<=U#{row}, U#{row}<=V#{row}, V#{row}<=W#{row}, W#{row}<=X#{row}), "⤴️", "")], #T
            shist.dig(0, :net_income), #U
            shist.dig(1, :net_income), #V
            shist.dig(2, :net_income), #W
            shist.dig(3, :net_income), #X

            shist.dig(0, :eps),
            shist.dig(1, :eps),
            shist.dig(2, :eps),
            shist.dig(3, :eps),

            shist.dig(0, :operation_income),
            shist.dig(1, :operation_income),
            shist.dig(2, :operation_income),
            shist.dig(3, :operation_income),

            shist.dig(0, :ordinal_income),
            shist.dig(1, :ordinal_income),
            shist.dig(2, :ordinal_income),
            shist.dig(3, :ordinal_income),

            shist.dig(0, :bps),
            shist.dig(1, :bps),
            shist.dig(2, :bps),
            shist.dig(3, :bps)
          ].map! { _1 || "-" },
          style: column_styles

          xlsx.serialize("output.xlsx")

          random_sleep
        end
      end

      $stderr.puts "Writing output file"
      xlsx.serialize("output.xlsx")
    end
  end
end
