require "yaml"
require "oj"
require "commit-live/lesson/current"
require "commit-live/lesson/status"
require "commit-live/api"
require "commit-live/netrc-interactor"
require "commit-live/tests/strategies/python-test"

module CommitLive
	class Test
		attr_reader :git

		REPO_BELONGS_TO_US = [
			'commit-live-students'
		]

		def initialize()
			check_lesson_dir
			check_if_practice_lesson
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
			@git = set_git
			netrc = CommitLive::NetrcInteractor.new()
			netrc.read(machine: 'ga-extra')
			username = netrc.login
			if git.remote.url.match(/#{username}/i).nil? && git.remote.url.match(/#{REPO_BELONGS_TO_US.join('|').gsub('-','\-')}/i).nil?
				put_error_msg
			end
		end

		def repo_name(remote: remote_name)
			url = git.remote(remote).url
			url.match(/^.+[\w-]+\/(.*?)(?:\.git)?$/)[1]
		end

		def lesson_name
			repo_name(remote: 'origin')
		end

		def put_error_msg
			puts "It doesn't look like you're in a lesson directory."
			puts 'Please cd into an appropriate directory and try again.'
			exit 1
		end

		def run(updateStatus = true)
			clear_changes_in_tests
			puts 'Testing lesson...'
			strategy.check_dependencies
			strategy.configure
			results = strategy.run
			if updateStatus
				if results
					# test case passed
					puts 'Great! You have passed all the test cases.'
					puts 'Use `clive submit` to push your changes.'
					CommitLive::Status.new().update('test_case_pass', lesson_name)
				else
					# test case failed
					puts 'Oops! You still have to pass all the test cases.'
					CommitLive::Status.new().update('test_case_fail', lesson_name)
				end
			end
			if strategy.results
				dump_results
			end
			strategy.cleanup
			return results
		end

		def strategy
			@strategy ||= strategies.map{ |s| s.new() }.detect(&:detect)
		end

		def clear_changes_in_tests
			system("git checkout HEAD -- tests/")
		end

		private

		def check_if_practice_lesson
			lesson = CommitLive::Current.new
			lesson.getCurrentLesson(lesson_name)
			lessonType = lesson.getValue('type')
			if lessonType == "PRACTICE"
				puts "This is a practice lesson. No need to run test on it."
				exit 1
			end
		end

		def dump_results
			begin
				Timeout::timeout(15) do
					api = CommitLive::API.new
					netrc = CommitLive::NetrcInteractor.new()
					netrc.read
					token = netrc.password
					url = URI.escape("/v1/dumps")
					response = api.post(
						url,
						headers: {
							'access-token' => "#{token}",
							'content-type' => 'application/json',
						},
						body: {
							'data' => Oj.dump(strategy.results, mode: :compat),
							'track_slug' => lesson_name
						}
					)
					if response.status != 201
						puts "Error while dumping test results."
					end
				end
			rescue Timeout::Error
				puts "Error while dumping test results."
				exit
			end
		end

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
