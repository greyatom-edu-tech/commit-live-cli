require "commit-live/api"
require "commit-live/netrc-interactor"
require "commit-live/sentry"
require "json"

module CommitLive
	class Current
		attr_accessor :lesson, :netrc, :sentry

		def initialize()
			@netrc = CommitLive::NetrcInteractor.new()
			@sentry = CommitLive::Sentry.new()
		end

		def getCurrentLesson(puzzle_name)
			if puzzle_name.empty?
				puts "Please specify a Track Slug"
				exit
			end
			getLesson(puzzle_name)
		end

		def token
			netrc.read
			netrc.password
		end

		def getLesson(track_slug)
			begin
				Timeout::timeout(15) do
					response = CommitLive::API.new().get(
						"/v2/user/track/#{track_slug}",
						headers: { 'Authorization' => "#{token}" }
					)
					if response.status == 200
						@lesson = JSON.parse(response.body)
					elsif response.status == 404
						puts "Oops you are trying to access a non-existent lesson."
						exit
					else
						sentry.log_message("Get Lesson Failed",
							{
								'url' => "/v2/user/track/#{track_slug}",
								'response-body' => response.body,
								'response-status' => response.status
							}
						)
					end
				end
			rescue Timeout::Error
				puts "Error while getting current lesson."
				puts "Please check your internet connection."
				exit
			end
		end

		def getAttr(attr)
			if !attr.nil?
				lesson.fetch(attr)
			end
		end

		def getValue(key)
			lessonData = getAttr('data')
			lessonData[key]
		end
		
	end
end