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

		desc "setup", "This will ask for your User-ID & Access Token"
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

		desc "open <track-slug>", "This will fork given assignment. (for eg. clive open <track-slug>)"
		def open(track_slug)
			# Fork and Clone User's current lesson
			lab_name = CommitLive::Puzzle::Parser.new(track_slug.join(' ')).parse!
			CommitLive::Open.new().openALesson(lab_name)
		end

		desc "submitn <track-slug>", "This will submit your work"
		def submit(track_slug)
			CommitLive::Submit.new().run(track_slug)
		end

		desc "test <track-slug>", "This will test your assignment. (for eg. clive test <track-slug>)"
		def test(track_slug)
			CommitLive::Test.new(track_slug).run
		end

		desc 'version, -v, --version', 'Display the current version of the CommitLive gem'
		def version
			puts CommitLive::Cli::VERSION
		end
	end
end