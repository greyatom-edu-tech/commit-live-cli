require "commit-live/netrc-interactor"
require "commit-live/sentry"
require "commit-live/api"
require "octokit"

module CommitLive
	class Github
		attr_accessor :netrc, :post_details, :sentry
		def initialize()
			@netrc = CommitLive::NetrcInteractor.new()
			@sentry = CommitLive::Sentry.new()
		end

		def token
			netrc.read
			netrc.password
		end

		def owner
			netrc.read(machine: 'ga-extra')
			netrc.login
		end

		def getAttr(attr)
			if !attr.nil?
				post_details.fetch(attr)
			end
		end

		def getValue(key)
			data = getAttr('data')
			data[key]
		end

		def post(repo_name, isFork = false)
			enc_url = "/v2/github/createPullRequest"
			log_title = "#{owner} - Pull Request Failed"
			if isFork
				enc_url = URI.escape("/v2/github/createFork")
				log_title = "#{owner} - Lesson Forked Failed"
			end
			begin
				Timeout::timeout(60) do
					response = CommitLive::API.new().post(
						enc_url,
						headers: {
							'Authorization' => "#{token}",
							'Content-Type' => 'application/json'
						},
						body: {
							"repoUrl": repo_name
						}
					)
					@post_details = JSON.parse(response.body)
					if response.status != 200
						sentry.log_message(log_title,
							{
								'url' => enc_url,
								'repo_name' => repo_name,
								'response-body' => response.body,
								'response-status' => response.status
							}
						)
					end
				end
			rescue Timeout::Error
				sentry.log_message(log_title,
					{
						'url' => enc_url,
						'track_name' => repo_name
					}
				)
			end
		end
	end
end