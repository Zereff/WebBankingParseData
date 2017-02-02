require 'rubygems'
require 'watir'
require 'nokogiri'
require 'json'
require 'io/console'
require 'date'
require 'pp'


BASE_URL = 'wb.micb.md'
ACCOUNTS_URL = 'wb.micb.md/way4u-wb2/api/v2/contracts'
TRANSACTIONS_URL = 'wb.micb.md/way4u-wb2/api/v2/history'


puts '[Sign in system wb.micb.md]'
puts 'Login:'
login = gets.chomp

puts 'Password:'
password = STDIN.noecho(&:gets)

browser = Watir::Browser.new :firefox, :profile => 'default'
browser.goto BASE_URL
browser.text_field(name: 'login').set(login)
browser.text_field(name: 'password').set(password)
browser.button(class: 'wb-button').click
browser.button(class: 'wb-button').wait_while_present


def get_last_months(m) 
	d = Date.today.strftime('%d-%m-%Y').split('-')

	day   = d[0].to_i;
	month = d[1].to_i;
	year  = d[2].to_i;

	today = Date.new(year, month, day)

	return (today << m).to_s
end


browser.goto ACCOUNTS_URL
get_accounts_page = Nokogiri::HTML(browser.html)

history_date = get_last_months(2)

browser.goto "#{TRANSACTIONS_URL}?from=#{history_date}"
get_transactions_page = Nokogiri::HTML(browser.html)

accounts_json_reply = JSON.parse(get_accounts_page.css('pre').text)
transactions_json_reply = JSON.parse(get_transactions_page.css('pre').text)


accounts_hsh = {}
accounts_arr = []
accounts_json_reply.each do |elm|
	accounts_arr.push(
		"id"       => elm['id'],
		"name"     => elm['number'],
		"balance"  => elm['balances']['available']['value'],
		"currency" => elm['currency'],
		"nature"   => elm['type']
	)
end


transactions_arr = []
transactions_json_reply.each do |elm|

	amount      = elm['totalAmount'] != nil ? elm['totalAmount']['value'] : ''
	currency    = elm['totalAmount'] != nil ? elm['totalAmount']['currency'] : ''
	description = elm['description'] != nil ? elm['description'] : ''

	transactions_arr.push(
		"account_id"  => elm['contractId'],
		"date"        => elm['operationTime'].sub(/[.]\S+/, 'Z'),
		"description" => description,
		"amount"      => amount,
		"currency"    => currency
	)
end


browser.quit


accounts_final_arr = []
accounts_arr.each do |acc_elm|
	transactions_final_arr = []
	transactions_arr.each do |trs_elm|
		if trs_elm['account_id'] == acc_elm['id']
			transactions_final_arr.push(trs_elm)
		end
	end

	accounts_final_arr.push(
		acc_elm.merge('transactions' => transactions_final_arr)
	)
end

accounts_hsh['accounts'] = accounts_final_arr


def record_file(data, file_name)
	my_local_file = open(file_name, 'w') 
	
	my_local_file.write(data)
	
	my_local_file.close
end


record_file(accounts_hsh, 'output.json')

pp accounts_hsh