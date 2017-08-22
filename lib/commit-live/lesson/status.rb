require "commit-live/api"
require "commit-live/netrc-interactor"
require "commit-live/sentry"
require "uri"

module CommitLive
	class Status
		attr_reader :api, :netrc, :sentry

		def initialize()
			@api = CommitLive::API.new
			@netrc = CommitLive::NetrcInteractor.new()
			@sentry = CommitLive::Sentry.new()
		end

		def token
			netrc.read
			netrc.password
		end

		def update(type, trackName)
			enc_url = URI.escape("/v1/user/track/#{trackName}")
			begin
				Timeout::timeout(60) do
					response = api.post(
						enc_url,
						headers: { 'access-token' => "#{token}" },
						params: { 
							'method' => 'assignment_status',
							'action' => type
						}
					)
					if response.status != 202
						sentry.log_message("Update Lesson Status Failed",
							{
								'url' => enc_url,
								'track_name' => trackName,
								'params' => {
									'method' => 'assignment_status',
									'action' => type
								},
								'response-body' => response.body,
								'response-status' => response.status
							}
						)
					end
				end
			rescue Timeout::Error
				puts "Error while updating lesson status."
				sentry.log_message("Update Lesson Status Failed",
					{
						'url' => enc_url,
						'track_name' => trackName,
						'params' => {
							'method' => 'assignment_status',
							'action' => type
						},
					}
				)
			end
		end
	end
end