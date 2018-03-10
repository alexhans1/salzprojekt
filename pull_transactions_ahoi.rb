require 'net/http'
require 'uri'
require 'json'
require 'date'
require 'time'
require 'base64'
require 'securerandom'

# Step 1
# obtain AHOI banking token
encodedClientToken = Base64.urlsafe_encode64(ENV['ahoiClientId'] + ':' + ENV['ahoiClientSecret'])
authObj = {
	"installationId": ENV['ahoiInstallationId'],
	"nonce": SecureRandom.urlsafe_base64(32)[0...32],
	"timestamp": Time.now.utc.iso8601
}.to_json
x_Authorization_token = Base64.urlsafe_encode64(authObj.to_s)

uri = URI.parse('https://banking-sandbox.starfinanz.de/auth/v1/oauth/token?grant_type=client_credentials')
req = Net::HTTP::Post.new(uri.request_uri)
req['Authorization'] = 'Basic ' + encodedClientToken
req['X-Authorization-Ahoi'] = x_Authorization_token
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
res = http.request(req)

if res.code == '200'
	data = JSON.parse(res.body)
	$registration_token = data['access_token']
	puts $registration_token
	puts
else
	puts res.code
	puts res
	abort("Failed to get registration token")
end

# Step 2
# Create AHOI Access
puts 'Creating AHOI Access'
puts
uri = URI.parse('https://banking-sandbox.starfinanz.de/ahoi/api/v2/accesses')
req = Net::HTTP::Post.new(uri.request_uri)
req['Authorization'] = 'Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzY29wZSI6WyJBQ0NFU1NfQyIsIkFDQ0VTU19SIiwiQUNDRVNTX1UiLCJBQ0NFU1NfRCIsIkFDQ09VTlRfUiIsIkFDQ09VTlRfRCIsIkFDQ09VTlRfVSIsIlBVQktFWV9SIiwiRk9SRUNBU1RfUiIsIlRYX1NVTU1BUllfUiIsIk5PVElGSUNBVElPTl9DIiwiTk9USUZJQ0FUSU9OX1IiLCJOT1RJRklDQVRJT05fVSIsIk5PVElGSUNBVElPTl9EIiwiTl9UQVJHRVRfQyIsIk5fVEFSR0VUX1IiLCJOX1RBUkdFVF9VIiwiTl9UQVJHRVRfRCIsIlBST1ZJREVSX1IiLCJUWF9QQVRURVJOX0MiLCJUWF9QQVRURVJOX1IiLCJUWF9QQVRURVJOX1UiLCJUWF9QQVRURVJOX0QiLCJUUkFOU0FDVElPTl9SIiwiVFJBTlNGRVJfQyIsIkVOQ19ESVMiXSwiQ09OVEVYVF9JRCI6InEyb3RqYmxTS0Vrd200MzlIYlBwN3ZSaUIzNWNucHozSk9wRzRKR3ZLL1cxblZmT0d6dUkzV1huVG9RSHhYY1QiLCJleHAiOjE1MjA2MjU0MjYsImp0aSI6Ijg0NWM3ZjhmLTU4ZjctNGIzMy1hY2I5LTJhMjgzNzAyMTk4NSIsImNsaWVudF9pZCI6IlNCTV9Cdk5rTkxCdEJ1eCJ9.HeN3hdCaP2AT5v8ghM1kLYerwI7JI2rRJZny4kdBnkEBvC3CBE0Pzp04umhKrsX21HFxJzA_5rKu3AoyDjHfoy8sjIZXzGUGVQVi8druOWibMN57oTHCc34CfwvPzJHcqyOg-Lg7Is1U3XW8zsY7fk-AOkot94UHdC6o1en1_sQbNlHqV_fF_Jp0r5DbtwytLaRlh3J03mq8mgohEBHFa68JRCSNHOUfAMwxBeCxC7QOpa5Ybf8fbRLT-t_xyjHQ8xrxeaJwFimIP8l48VYJW8vBh594Lrf_lKt_yalYT9YGOs1JCuOSz0cRV4pYCLuZVsZN6EKVFSwhGsQrPmIG-A'
req['Content-Type'] = 'application/json'
req.body = {
	"providerId": 43,
	"type": "BankAccess",
	"accessFields": {
	  "USERNAME": ENV['bankUserName'],
	  "PIN": ENV['bankUserPassword']
	}
  }.to_json
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
res = http.request(req)

if res.code.start_with?('2')
	data = JSON.parse(res.body)
	$access_id = data['id'].to_s
	puts $access_id
	puts
else
	puts res.code
	puts res
	abort("Failed to create AHOI Access")
end

# Step 3
# Get Accounts
uri = URI.parse('https://banking-sandbox.starfinanz.de/ahoi/api/v2/accesses/' + $access_id.to_s + '/accounts')
req = Net::HTTP::Get.new(uri.request_uri)
req['Authorization'] = 'Bearer ' + $registration_token
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
res = http.request(req)

if res.code.start_with?('2')
	data = JSON.parse(res.body)
	$accountId = data[0]['id']
	puts $accountId
	puts
else
	puts res.code
	puts res
	abort("Failed to get accounts")
end

# Step 4
# Get Transactions
uri = URI.parse('https://banking-sandbox.starfinanz.de/ahoi/api/v2/accesses/' + $access_id.to_s + '/accounts/' + $accountId.to_s + '/transactions?from=' + (Date.today - 1).to_s)
req = Net::HTTP::Get.new(uri.request_uri)
req['Authorization'] = 'Bearer ' + $registration_token
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
res = http.request(req)

if res.code.start_with?('2')
	data = JSON.parse(res.body)
	transactions = data
	if transactions != []
		File.open("./transaction_ahoi_" + Time.now.strftime('%Y-%m-%d_%H-%M-%S.%L') + ".json", "w") do |f|
			f.write(transactions.to_json)
		end
		puts 'Create file with latest transactions'
		puts
	else
		puts 'No new transactions'
		puts
	end
	puts $transactions
	puts
else
	puts res.code
	puts res
	abort("Failed to get transactions")
end
