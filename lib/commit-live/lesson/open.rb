require "commit-live/lesson/current"
require "commit-live/lesson/status"
require "commit-live/api"
require "commit-live/github"
require "commit-live/sentry"
require "octokit"
require "git"
require "oj"

module CommitLive
	class Open
		attr_reader :rootDir, :lesson, :forked_ssh_url, :lesson_status, :sentry

		HOME_DIR = File.expand_path("~")
		ALLOWED_TYPES = ["CODE", "PRACTICE"]

		def initialize()
			if File.exists?("#{HOME_DIR}/.ga-config")
				@rootDir = YAML.load(File.read("#{HOME_DIR}/.ga-config"))[:workspace]
			end
			@lesson = CommitLive::Current.new
			@lesson_status = CommitLive::Status.new
			@sentry = CommitLive::Sentry.new()
		end

		def ssh_url
			if lesson_type === "PRACTICE"
				"git@github.com:#{lesson_repo}.git"
			else
				forked_ssh_url
			end
		end

		def lesson_name
			lesson.getValue('titleSlug')
		end

		def track_slug
			lesson.getValue('titleSlugTestCase')
		end

		def lesson_type
			lesson.getValue('type')
		end

		def is_project_assignment
			isProjectAssignment = lesson.getValue('isProjectAssignment')
			!isProjectAssignment.nil? && isProjectAssignment == 1
		end

		def lesson_forked
			forked = lesson.getValue('forked')
			!forked.nil? && forked == 1
		end

		def is_project
			isProject = lesson.getValue('isProject')
			!isProject.nil? && isProject == 1
		end

		def lesson_repo
			lesson.getValue('repoUrl')
		end

		def openALesson(puzzle_name)
			# get currently active lesson
			puts "Getting lesson..."
			lesson.getCurrentLesson(puzzle_name)

			if !ALLOWED_TYPES.include? lesson_type
				puts "This is a read only lesson!"
				exit
			end

			if !File.exists?("#{rootDir}/#{lesson_name}")
				# fork lesson repo via github api
				if lesson_type == "CODE"
					forkCurrentLesson
				end
				# clone forked lesson into machine
				cloneCurrentLesson
				# change group owner
				change_grp_owner
				# lesson forked API change
				if lesson_type == "PRACTICE" || is_project
					open_lesson
				end
			else
				open_lesson
			end
			if !is_project && lesson_type == "CODE" && !lesson_forked
				lesson_status.update('forked', track_slug)
			end
			# install dependencies
			# cd into it and invoke bash
			cdToLesson
		end

		def forkCurrentLesson
			puts "Forking lesson..."
			github = CommitLive::Github.new()
			github.post(lesson_repo, true)
			@forked_ssh_url = github.getValue("sshUrl")
		end

		def cloneCurrentLesson
			puts "Cloning lesson..."
			begin
				Git.clone(ssh_url, lesson_name, path: rootDir)
			rescue Git::GitExecuteError => err
				sentry.log_exception(err,
					{
						'event': 'cloning',
						'lesson_name' => lesson_name,
						'current-directory' => Dir.pwd
					}
				)
			end
		end

		def change_grp_owner
			system("chgrp -R ubuntu #{rootDir}/#{lesson_name}")
		end

		def cdToLesson
			puts "Opening lesson..."
			Dir.chdir("#{rootDir}/#{lesson_name}")
			puts "Done."
			if File.exists?("#{HOME_DIR}/.lastdirectory")
				filename = "#{HOME_DIR}/.lastdirectory"
				File.open(filename, 'w') do |out|
					out << "#{rootDir}/#{lesson_name}"
				end
			end
			exec("#{ENV['SHELL']} -l")
		end

		def open_lesson
			begin
				Timeout::timeout(15) do
					api = CommitLive::API.new("https://chat.commit.live")
					netrc = CommitLive::NetrcInteractor.new()
					netrc.read(machine: 'ga-extra')
					username = netrc.login
					url = URI.escape("/send/#{username}")
					message = {
						'type': 'open-lesson',
						'title': is_project_assignment ? track_slug : lesson_name,
						'message': {
							'fileName': 'readme.md',
							'type': 'forked',
							'value': true
						}
					}
					response = api.post(
						url,
						headers: {
							'content-type': 'application/json',
						},
						body: {
							'message': Oj.dump(message, mode: :compat),
						}
					)
				end
			rescue Timeout::Error
				puts "The Assignment already exists! Use the File-Browser to open files under it."
				exit
			end
		end
	end
end