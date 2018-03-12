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
req['Authorization'] = 'Bearer ' + $registration_token
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
