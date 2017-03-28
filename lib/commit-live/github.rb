require "commit-live/netrc-interactor"
require 'octokit'

module CommitLive
	class Github
		attr_accessor :client
		def initialize()
	      	netrc = CommitLive::NetrcInteractor.new()
	      	netrc.read
	      	token = netrc.password
	      	if !token.nil?
				@client = Octokit::Client.new(:access_token => token)
	      	end
		end
	end
end