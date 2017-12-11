require "yaml"
require "oj"
require "commit-live/lesson/current"
require "commit-live/lesson/status"
require "commit-live/api"
require "commit-live/sentry"
require "commit-live/netrc-interactor"
require "commit-live/tests/strategies/python-test"

module CommitLive
	class Test
		attr_reader :git, :sentry, :track_slug, :lesson, :rootDir

		HOME_DIR = File.expand_path("~")
		REPO_BELONGS_TO_US = [
			'commit-live-students'
		]

		def initialize(trackSlug)
			@track_slug = trackSlug
			check_lesson_dir
			check_if_practice_lesson
			check_if_user_in_right_folder
			die if !strategy
			@sentry = CommitLive::Sentry.new()
			if File.exists?("#{HOME_DIR}/.ga-config")
				@rootDir = YAML.load(File.read("#{HOME_DIR}/.ga-config"))[:workspace]
			end
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
			results = strategy.run(test_case_dir_path)
			if strategy.results
				strategy.print_results
			end
			if updateStatus
				if results
					# test case passed
					puts 'Great! You have passed all the test cases.'
					puts 'Use `clive submit` to push your changes.'
					CommitLive::Status.new().update('testCasesPassed', track_slug)
				else
					# test case failed
					puts 'Oops! You still have to pass all the test cases.'
					CommitLive::Status.new().update('testCasesFailed', track_slug)
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
			system("git checkout HEAD -- #{test_case_dir_path}")
		end

		def test_case_dir_path
			filePath = ""
			filePath += "#{test_slug}/" if is_project_assignment
			filePath += "tests/"
			return filePath
		end

		def test_slug
			lesson.getValue('testCase')
		end

		def title_slug
			lesson.getValue('titleSlug')
		end

		def is_project_assignment
			isProjectAssignment = lesson.getValue('isProjectAssignment')
			!isProjectAssignment.nil? && isProjectAssignment == 1
		end

		def is_project
			isProject = lesson.getValue('isProject')
			!isProject.nil? && isProject == 1
		end

		def is_practice
			lessonType = lesson.getValue('type')
			!lessonType.nil? && lessonType == "PRACTICE"
		end

		private

		def check_if_practice_lesson
			@lesson = CommitLive::Current.new
			lesson.getCurrentLesson(track_slug)
			if is_project || is_practice
				puts 'This is a Project. Go to individual assignments and follow intructions given on how to pass test cases for them.' if is_project
				puts 'This is a Practice Lesson. No need to run tests on it.' if is_practice
				exit 1
			end
		end

		def check_if_user_in_right_folder
			dirname = File.basename(Dir.getwd)
			if dirname != title_slug
				puts "It seems that you are in the wrong directory."
				puts "Use the following command to go there"
				puts "\n\n\t`cd ~/Workspace/code/#{title_slug}/`"
				puts "\nThen use the `clive test <track-slug>` command"
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
					url = URI.escape("/v2/dumps")
					response = api.post(
						url,
						headers: {
							'Authorization' => "#{token}",
							'Content-Type' => 'application/json',
						},
						body: {
							'data' => Oj.dump(strategy.results, mode: :compat),
							'titleSlugTestCase' => track_slug
						}
					)
					if response.status != 200
						sentry.log_message("Test Results Dump Failed",
							{
								'url' => url,
								'track-slug' => track_slug,
								'results' => strategy.results,
								'response-body' => response.body,
								'response-status' => response.status
							}
						)
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
