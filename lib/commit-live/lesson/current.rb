require "commit-live/api"
require 'json'

module CommitLive
	class Current
		attr_accessor :lesson

		def getCurrentLesson(*puzzle_name)
			begin
				Timeout::timeout(15) do
					response = CommitLive::API.new().get('/bins/k8lsj')
					if response.status == 200
						@lesson = JSON.parse(response.body)
						# @lessonRepo = lesson.fetch('github_repo')
						# @lessonName = lesson.fetch('lesson_name')
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