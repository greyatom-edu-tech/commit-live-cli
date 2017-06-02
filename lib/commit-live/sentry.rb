require "commit-live/netrc-interactor"
require "sentry-raven"

module CommitLive
	class Sentry
		attr_accessor :netrc

		def initialize()
			@netrc = CommitLive::NetrcInteractor.new()
		end

		def token
			netrc.read
			netrc.password
		end

		def username
			netrc.read(machine: 'ga-extra')
			netrc.login
		end

		def user_info
			{
				'username' => username,
				'token' => token
			}
		end

		def merge_user_info_with_other_args(other_args)
			user_info.merge(other_args)
		end

		def log_message(message, other_args)
			Raven.capture_message(message,
				:extra => merge_user_info_with_other_args(other_args)
			)
			puts "Something went wrong. Commit.Live Admin has been notified about the issue. Please wait until further instructions."
			exit 1
		end

		def log_exception(the_exception, other_args)
			Raven.capture_message(the_exception,
				:extra => merge_user_info_with_other_args(other_args)
			)
			puts "Something went wrong. Commit.Live Admin has been notified about the issue. Please wait until further instructions."
			exit 1
		end
	end
end