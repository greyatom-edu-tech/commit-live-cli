require "commit-live/lesson/current"
require "commit-live/lesson/status"
require "commit-live/tests/runner"
require "commit-live/netrc-interactor"
require "commit-live/github"

module CommitLive
	class Submit
		class GitHelper
			attr_reader   :git, :currentLesson, :netrc, :status
			attr_accessor :remote_name

			REPO_BELONGS_TO_US = [
				'commit-live-students'
			]

			def initialize()
				@git = setGit
				@netrc = CommitLive::NetrcInteractor.new()
				@currentLesson = CommitLive::Current.new
				@status = CommitLive::Status.new
			end

			def commitAndPush
				checkRemote
				testCasePassed = CommitLive::Test.new().run(false)
				if testCasePassed
					addChanges
					commitChanges

					push
					createPullRequest
					update_lesson_status
				else
					puts "..."
					puts "Please make sure all test cases pass before submitting!"
					exit
				end
			end

			private

			def setGit
				begin
					Git.open(FileUtils.pwd)
				rescue ArgumentError => e
					if e.message.match(/path does not exist/)
						puts "It doesn't look like you're in a lesson directory."
						puts 'Please cd into an appropriate directory and try again.'

						exit 1
					else
						puts 'Sorry, something went wrong. Please try again.'
						exit 1
					end
				end
			end

			def checkRemote
				netrc.read(machine: 'ga-extra')
				username = netrc.login
				if git.remote.url.match(/#{username}/i).nil? && git.remote.url.match(/#{REPO_BELONGS_TO_US.join('|').gsub('-','\-')}/i).nil?
					puts "It doesn't look like you're in a lesson directory."
					puts 'Please cd into an appropriate directory and try again.'
					exit 1
				else
					self.remote_name = git.remote.name
				end
			end

			def addChanges
				puts 'Adding changes...'
				git.add(all: true)
			end

			def commitChanges
				puts 'Committing changes...'
				begin
					git.commit('Done')
				rescue Git::GitExecuteError => e
					if e.message.match(/nothing to commit/)
						puts "It looks like you have no changes to commit."
						exit 1
					else
						puts 'Sorry, something went wrong. Please try again.'
						exit 1
					end
				end
			end

			def push()
				puts 'Pushing changes to GitHub...'
				push_remote = git.remote(self.remote_name)
				begin
					Timeout::timeout(15) do
						git.push(push_remote)
					end
				rescue Git::GitExecuteError => e
					puts 'There was an error while pushing. Please try again later.'
					puts e.message
					exit 1
				rescue Timeout::Error
					puts "Can't reach GitHub right now. Please try again."
					exit 1
				end
			end

			def createPullRequest
				puts 'Creating Pull Request...'
				lessonName = repo_name(remote: 'origin')
				currentLesson.getCurrentLesson(lessonName)
				userGithub = CommitLive::Github.new()
				netrc.read(machine: 'ga-extra')
				username = netrc.login
				begin
					Timeout::timeout(45) do
						lessonData = currentLesson.getAttr('data')
						parentRepo = lessonData['repo_url']
						pullRequest = userGithub.client.create_pull_request(
							parentRepo,
							'master',
							"#{username}:master",
							"PR by #{username}"
						)
						puts "Lesson submitted successfully!"
					end
				rescue Octokit::Error => err
					puts "Error while creating PR!"
					puts err
					exit 1
				rescue Timeout::Error
					puts "Please check your internet connection."
					exit 1
				end
			end

			def repo_name(remote: remote_name)
				url = git.remote(remote).url
				url.match(/^.+[\w-]+\/(.*?)(?:\.git)?$/)[1]
			end

			def update_lesson_status
				lessonName = repo_name(remote: 'origin')
				status.update('submitted_pull_request', lessonName)
			end
		end
	end
end
