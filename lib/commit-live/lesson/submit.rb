require 'commit-live/lesson/git-helper'
require 'octokit'

module CommitLive
	class Submit
		def run
		  	CommitLive::Submit::GitHelper.new().commitAndPush
		  	# Just to give GitHub a second to register the repo changes
		  	sleep(1)
		end
	end
end
