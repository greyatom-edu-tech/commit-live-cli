require "commit-live/lesson/current"
require "commit-live/netrc-interactor"
require "commit-live/api"
require "commit-live/github"
require 'octokit'
require 'git'

module CommitLive
	class Open
		attr_reader :lessonName, :rootDir, :lesson

		HOME_DIR = File.expand_path("~")

	    def initialize()
	      	if File.exists?("#{HOME_DIR}/.ga-config")
	      		@rootDir = YAML.load(File.read("#{HOME_DIR}/.ga-config"))[:workspace]
	      	end
	      	@lesson = CommitLive::Current.new
	    end

		def openALesson(*puzzle_name)
			# get currently active lesson
			puts "Getting current lesson..."
			lesson.getCurrentLesson(puzzle_name)
			@lessonName = lesson.getAttr('lesson_name')
			if !File.exists?("#{rootDir}/#{lessonName}")
				# fork lesson repo via github api
				forkCurrentLesson
				# clone forked lesson into machine
				cloneCurrentLesson
				# change group owner
				change_grp_owner
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
					lessonRepo = lesson.getAttr('github_repo')
					forkedRepo = github.client.fork(lessonRepo)
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
	          		cloneUrl = lesson.getAttr('forked_repo')
	            	Git.clone("git@github.com:#{cloneUrl}.git", lessonName, path: rootDir)
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