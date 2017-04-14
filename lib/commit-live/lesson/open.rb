require "commit-live/lesson/current"
require "commit-live/lesson/status"
require "commit-live/netrc-interactor"
require "commit-live/api"
require "commit-live/github"
require 'octokit'
require 'git'

module CommitLive
	class Open
		attr_reader :lessonName, :rootDir, :lesson, :forkedRepo, :lesson_status

		HOME_DIR = File.expand_path("~")

		def initialize()
			if File.exists?("#{HOME_DIR}/.ga-config")
				@rootDir = YAML.load(File.read("#{HOME_DIR}/.ga-config"))[:workspace]
			end
			@lesson = CommitLive::Current.new
			@lesson_status = CommitLive::Status.new
		end

		def openALesson(puzzle_name)
			# get currently active lesson
			puts "Getting current lesson..."
			lesson.getCurrentLesson(puzzle_name)
			lessonData = lesson.getAttr('data')
			if !lessonData['current_track'].nil?
				@lessonName = lessonData['current_track']['track_slug']
			else
				@lessonName = lessonData['track_slug']
			end
			if !File.exists?("#{rootDir}/#{lessonName}")
				# fork lesson repo via github api
				forkCurrentLesson
				# clone forked lesson into machine
				cloneCurrentLesson
				# change group owner
				change_grp_owner
				# lesson forked API change
				puts 'Updating lesson status...'
				lesson_status.update('forked', lessonName)
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
					lessonData = lesson.getAttr('data')
					if !lessonData['current_track'].nil?
						lessonRepo = lessonData['current_track']['repo_url']
					else
						lessonRepo = lessonData['repo_url']
					end
					@forkedRepo = github.client.fork(lessonRepo)
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
					Git.clone(forkedRepo.ssh_url, lessonName, path: rootDir)
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
			results = system("chgrp -R ubuntu #{rootDir}/#{lessonName}")
			if results
				puts "..."
			else
				puts "Couldn't change group ownership"
			end
		end

		def cdToLesson
			puts "Opening lesson..."
			Dir.chdir("#{rootDir}/#{lessonName}")
			puts "Done."
			exec("#{ENV['SHELL']} -l")
		end
	end
end