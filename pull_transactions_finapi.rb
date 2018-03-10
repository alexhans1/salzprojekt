require 'net/http'
require 'uri'
require 'json'
require 'date'

# puts ENV['finApiClientID'][0...-1]
# abort()

# Step 1
# get FinAPI Access Token

client_id = ENV['finApiClientID']
client_secret = ENV['finApiClientSecret']
uri = URI('https://sandbox.finapi.io/oauth/token')
res = Net::HTTP.post_form(uri,
	'grant_type' => 'client_credentials',
	'client_id' => ENV['finApiClientID'],
	'client_secret' => ENV['finApiClientSecret']
)

if res.code == '200'
	data = JSON.parse(res.body)
	$access_token = data['access_token']
	puts $access_token
	puts
else
	puts res.code
	puts res.message
	abort("Failed to get access_token")
end

# Step 2
# get FinAPI User Token

uri = URI.parse('https://sandbox.finapi.io/oauth/token')
req = Net::HTTP::Post.new(uri.request_uri)
req['Authorization'] = 'Bearer ' + $access_token.to_s
req.set_form_data({
	'grant_type' => 'password',
	'client_id' => ENV['finApiClientID'].to_s,
	'client_secret' => ENV['finApiClientSecret'].to_s,
	'username' => ENV['finApiUserName'],
	'password' => ENV['finApiUserPassword']
})
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
res = http.request(req)

if res.code == '200'
	data = JSON.parse(res.body)
	$user_token = data['access_token']
	puts $user_token
	puts
else
	puts res.message
	abort("Failed to get user_token")
end

# Step 3
# Import Bank Connection if neccessary

# Step 3.1
# Check if a bank connection already exists

uri = URI.parse('https://sandbox.finapi.io/api/v1/bankConnections')
req = Net::HTTP::Get.new(uri.request_uri)
req['Authorization'] = 'Bearer ' + $user_token.to_s
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
res = http.request(req)

if res.code == '200'
	data = JSON.parse(res.body)
	connections = data['connections']
else
	puts res.message
	abort("Failed to get bank connections")
end

if connections == []
	puts 'no connections'
	puts

	# 3.2
	# if there are no connections import one

	uri = URI.parse('https://sandbox.finapi.io/api/v1/bankConnections/import')
	req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
	req['Authorization'] = 'Bearer ' + $user_token.to_s
	req.body = {
		bankId: '24353',
	 	bankingUserId: ENV['bankUserName'].to_s,
	 	bankingPin: ENV['bankUserPassword'].to_s,
	 	storePin: false
	 }.to_json
	http = Net::HTTP.new(uri.host, uri.port)
	http.use_ssl = true
	res = http.request(req)

	if res.code == '201'
		data = JSON.parse(res.body)
		puts data
		puts
	else
		puts 'Failed to import bank connection.'
		puts res.message
		puts res.code
		puts
	end
else
	puts 'has connections'
	puts

	# Step 3.3
	# Get status of connection import

	def getConnectionStatus (connectionID)

		uri = URI.parse(
			'https://sandbox.finapi.io/api/v1/bankConnections/' +
		 	connectionID.to_s
		)
		req = Net::HTTP::Get.new(uri.request_uri)
		req['Authorization'] = 'Bearer ' + $user_token.to_s
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		res = http.request(req)

		if res.code == '200'
			data = JSON.parse(res.body)
			updateStatus = data['updateStatus']
		else
			puts res.message
			abort("Failed to get update status")
		end

		updateStatus
	end

	connectionID = JSON.parse(connections[0].to_json.to_s)["id"]
	updateStatus = getConnectionStatus connectionID

	if updateStatus == 'READY'
		puts updateStatus
		puts

		# Step 4
		# Get Transactions

		uri = URI.parse('https://sandbox.finapi.io/api/v1/transactions?view=userView&' +
		'direction=income&' +
		'includeChildCategories=true&' +
		'page=1&' +
		'perPage=500&' +
		'minBankBookingDate=' + (Date.today - 1).to_s + '&' +
		'order=bankBookingDate%2Cdesc')
		req = Net::HTTP::Get.new(uri.request_uri)
		req['Authorization'] = 'Bearer ' + $user_token.to_s
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		res = http.request(req)

		if res.code == '200'
			data = JSON.parse(res.body)
			transactions = data['transactions']

			if transactions != []
				File.open("./transaction_" + Time.now.strftime('%Y-%m-%d_%H-%M-%S.%L') + ".json", "w") do |f|
					f.write(transactions.to_json)
				end
			else
				puts 'No new transactions'
				puts
			end
		else
			puts res.message
			abort("Failed to get transactions")
		end
		
	else
		sleep(10)
		# do it again
	end

end
