require "commit-live/api"
require "commit-live/netrc-interactor"
require 'json'
require 'yaml'

module CommitLive
	class User
		attr_reader :netrc

		DEFAULT_EDITOR = 'atom'

	    def initialize()
	      	@netrc = CommitLive::NetrcInteractor.new()
	    end

		def validate(token)
			puts "Authenticating..."
			begin
				Timeout::timeout(15) do
					response = CommitLive::API.new().get('/bins/c4vbn')
					if response.status == 200
						# Save valid user details in netrc
						user = JSON.parse(response.body)
						login, password = netrc.read
						if login.nil? || password.nil?
							save(user, token)
						else
							username = user.fetch('username')
							welcome(username)
						end
					else
						case response.status
			            when 401
			              puts "It seems your OAuth token is incorrect. Please retry with correct token."
			              exit 1
			            else
			              puts "Something went wrong. Please try again."
			              exit 1
			            end
					end
				end
			rescue Timeout::Error
				puts "Please check your internet connection."
				exit
			end
		end

		def save(userDetails, token)
			username = userDetails.fetch('username')
			github_uid = userDetails.fetch('github_uid')
			netrc.write(new_login: 'greyatom', new_password: token)
			netrc.write(machine: 'ga-extra', new_login: username, new_password: github_uid)
			welcome(username)
		end

		def setDefaultWorkspace
			workspaceDir = File.expand_path('~/Workspace/code')
			configPath = File.expand_path('~/.ga-config')

			FileUtils.mkdir_p(workspaceDir)
			FileUtils.touch(configPath)

			data = YAML.dump({ workspace: workspaceDir, editor: DEFAULT_EDITOR })

			File.write(configPath, data)
		end

	    def confirmAndReset
	      	if confirmReset?
	        	netrc.delete!(machine: 'ga-config')
	        	netrc.delete!(machine: 'ga-extra')
	        	puts "Sorry to see you go!"
        	else
        		puts "Thanks for being there with us!"
	      	end

	      	exit
	    end

	    def confirmReset?
	      	puts "This will remove your existing login configuration and reset.\n"
	      	print "Are you sure you want to do this? [yN]: "

	      	response = STDIN.gets.chomp.downcase

	      	!!(response == 'yes' || response == 'y')
	    end

		def welcome(username)
			puts "Welcome, #{username}!"
		end
	end
end