require "commit-live/user"
require "commit-live/netrc-interactor"
require "commit-live/tests/runner"
require "commit-live/lesson/submit"
require "commit-live/lesson/open"
require "commit-live/lesson/parser"
require "thor"

module CommitLive
	class CLI < Thor
		desc "hello", "This will greet you"
		def hello()
			puts "Hello World!"
		end

		desc "setup", "This will ask for token"
		def setup(retries: 5)
			# Check if token already present
			login, password = CommitLive::NetrcInteractor.new().read
			if login.nil? || password.nil?
				print 'Enter User-ID here and press [ENTER]: '
				login = STDIN.gets.chomp
				if login.empty?
					puts "No User-ID provided."
					exit
				end
				print 'Enter Access token here and press [ENTER]: '
				password = STDIN.gets.chomp
				if password.empty?
					puts "No token provided."
					exit
				end
			end
			# Check if token is valid
			user = CommitLive::User.new()
			user.validate(login, password)
			user.setDefaultWorkspace
		end

		desc "reset", "This will forget you"
		def reset()
			CommitLive::User.new().confirmAndReset
		end

		desc "open", "This will fork new work"
		def open(*puzzle_name)
			# Fork and Clone User's current lesson
			lab_name = CommitLive::Puzzle::Parser.new(puzzle_name.join(' ')).parse!
			CommitLive::Open.new().openALesson(lab_name)
		end

		desc "submit", "This will submit your work"
		def submit()
			CommitLive::Submit.new().run
		end

		desc "test", "This will test you"
		def test()
			CommitLive::Test.new().run
		end

		desc 'version, -v, --version', 'Display the current version of the CommitLive gem'
		def version
			puts CommitLive::Cli::VERSION
		end
	end
end