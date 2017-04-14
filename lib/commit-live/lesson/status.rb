require "commit-live/api"
require "commit-live/netrc-interactor"
require 'uri'

module CommitLive
	class Status
		attr_reader :api, :netrc

		def initialize()
			@api = CommitLive::API.new
			@netrc = CommitLive::NetrcInteractor.new()
		end

		def update(type, trackName)
			begin
				Timeout::timeout(15) do
					netrc.read
					token = netrc.password
					enc_url = URI.escape("/v1/user/track/#{trackName}")
					response = api.post(
						enc_url,
						headers: { 'access-token' => "#{token}" },
						params: { 
							'method' => 'assignment_status',
							'action' => type
						}
					)
					if response.status == 202
						puts "Lesson Status updated!"
					else
						puts "Something went wrong. Please try again."
						exit 1
					end
				end
			rescue Timeout::Error
				puts "Error while updating lesson status."
				puts "Please check your internet connection."
				exit
			end
		end
	end
end