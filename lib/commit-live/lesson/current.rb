require "commit-live/api"
require "commit-live/netrc-interactor"
require 'json'

module CommitLive
	class Current
		attr_accessor :lesson, :netrc

		def initialize()
			@netrc = CommitLive::NetrcInteractor.new()
		end

		def getCurrentLesson(puzzle_name)
			url = '/v1/current_lesson'
			if !puzzle_name.empty?
				url = "/v1/user/lesson/#{puzzle_name}"
			end
			getLesson(url)
		end

		def getLesson(url)
			begin
				Timeout::timeout(15) do
					netrc.read
					token = netrc.password
					response = CommitLive::API.new().get(
						url,
						headers: { 'access-token' => "#{token}" }
					)
					if response.status == 200
						@lesson = JSON.parse(response.body)
					else
						puts "Something went wrong. Please try again."
						exit 1
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
		
	end
end