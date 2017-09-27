require "commit-live/lesson/git-helper"
require "octokit"

module CommitLive
	class Submit
		def run(track_slug)
			CommitLive::Submit::GitHelper.new(track_slug).commitAndPush
			# Just to give GitHub a second to register the repo changes
			sleep(1)
		end
	end
end
