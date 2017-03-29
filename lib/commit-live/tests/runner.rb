require 'yaml'
require "commit-live/lesson/status"
require "commit-live/netrc-interactor"
require 'commit-live/tests/strategies/python-test'

module CommitLive
	class Test
		REPO_BELONGS_TO_US = [
			'commit-live-students'
		]

		def initialize()
			check_lesson_dir
			die if !strategy
		end

		def set_git
			begin
				Git.open(FileUtils.pwd)
			rescue => e
				put_error_msg
			end
		end

		def check_lesson_dir
			git = set_git
			netrc = CommitLive::NetrcInteractor.new()
			netrc.read(machine: 'ga-extra')
			username = netrc.login
			if git.remote.url.match(/#{username}/i).nil? && git.remote.url.match(/#{REPO_BELONGS_TO_US.join('|').gsub('-','\-')}/i).nil?
				put_error_msg
			end
		end

		def put_error_msg
			puts "It doesn't look like you're in a lesson directory."
			puts 'Please cd into an appropriate directory and try again.'
			exit 1
		end

		def run
			strategy.check_dependencies
			strategy.configure
			results = strategy.run
			puts 'Updating lesson status...'
			lessonName = File.basename(Dir.getwd)
			if results
				# test case passed
				CommitLive::Status.new().update('test_case_pass', lessonName)
			else
				# test case failed
				CommitLive::Status.new().update('test_case_fail', lessonName)
			end
		end

		def strategy
			@strategy ||= strategies.map{ |s| s.new() }.detect(&:detect)
		end

		private

		def strategies
			[
				CommitLive::Strategies::PythonUnittest
			]
		end

		def die
			puts "This directory doesn't appear to have any specs in it."
			exit
		end
	end
end
