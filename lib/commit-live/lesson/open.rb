require "commit-live/lesson/current"
require "commit-live/lesson/status"
require "commit-live/api"
require "commit-live/github"
require 'octokit'
require 'git'
require "oj"

module CommitLive
	class Open
		attr_reader :rootDir, :lesson, :forkedRepo, :lesson_status

		HOME_DIR = File.expand_path("~")
		ALLOWED_TYPES = ["LAB", "PRACTICE"]

		def initialize()
			if File.exists?("#{HOME_DIR}/.ga-config")
				@rootDir = YAML.load(File.read("#{HOME_DIR}/.ga-config"))[:workspace]
			end
			@lesson = CommitLive::Current.new
			@lesson_status = CommitLive::Status.new
		end

		def ssh_url
			if lesson_type === "PRACTICE"
				"git@github.com:#{lesson_repo}.git"
			else
				forkedRepo.ssh_url
			end
		end

		def lesson_name
			lesson.getValue('track_slug')
		end

		def lesson_type
			lesson.getValue('type')
		end

		def lesson_forked
			lesson.getValue('forked')
		end

		def lesson_repo
			lesson.getValue('repo_url')
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
				if lesson_type == "LAB"
					forkCurrentLesson
				end
				# clone forked lesson into machine
				cloneCurrentLesson
				# change group owner
				change_grp_owner
				# lesson forked API change
				if lesson_type == "LAB" && !lesson_forked
					lesson_status.update('forked', lesson_name)
				end
				if lesson_type == "PRACTICE"
					open_lesson
				end
			end
			# install dependencies
			# cd into it and invoke bash
			cdToLesson
		end

		def forkCurrentLesson
			puts "Forking lesson..."
			github = CommitLive::Github.new()
			begin
				Timeout::timeout(15) do
					@forkedRepo = github.client.fork(lesson_repo)
				end
			rescue Octokit::Error => err
				puts "Error while forking!"
				puts err
				exit
			rescue Timeout::Error
				puts "Please check your internet connection."
				exit
			end
		end

		def cloneCurrentLesson
			puts "Cloning lesson..."
			begin
				Timeout::timeout(15) do
					Git.clone(ssh_url, lesson_name, path: rootDir)
				end
			rescue Git::GitExecuteError => err
				puts "Error while cloning!"
				puts err
				exit
			rescue Timeout::Error
				puts "Cannot clone this lesson right now. Please try again."
				exit
			end
		end

		def change_grp_owner
			system("chgrp -R ubuntu #{rootDir}/#{lesson_name}")
		end

		def cdToLesson
			puts "Opening lesson..."
			Dir.chdir("#{rootDir}/#{lesson_name}")
			puts "Done."
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
						'title': lesson_name
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
				puts "Open Lesson WebSocket call failed."
				exit
			end
		end
	end
end