require "faraday"

module CommitLive
	class API
		attr_reader :conn

		URL = 'http://api.greyatom.com'
		API_ROOT  = '/api/v1'

		def initialize()
			@conn = Faraday.new(url: URL) do |faraday|
				faraday.adapter Faraday.default_adapter
			end
		end

		def get(url, options = {})
			request :get, url, options
		end

		def post(url, options = {})
			request :post, url, options
		end
		
		private

		def request(method, url, options = {})
			begin
				connection = options[:client] || @conn
				connection.send(method) do |req|
					req.url url
					buildRequest(req, options)
				end
			rescue Faraday::ConnectionFailed
				puts "Connection error. Please try again."
			end
		end

		def buildRequest(request, options)
			buildHeaders(request, options[:headers])
			buildParams(request, options[:params])
			buildBody(request, options[:body])
		end

		def buildHeaders(request, headers)
			if headers
				headers.each do |header, value|
					request.headers[header] = value
				end
			end
		end

		def buildParams(request, params)
			if params
				params.each do |param, value|
					request.params[param] = value
				end
			end
		end

		def buildBody(request, body)
			if body
				request.body = Oj.dump(body, mode: :compat)
			end
		end
	end
end
