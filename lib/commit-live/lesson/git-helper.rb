require "commit-live/lesson/current"
require "commit-live/lesson/status"
require "commit-live/netrc-interactor"
require "commit-live/github"
require "commit-live/sentry"

module CommitLive
	class Submit
		class GitHelper
			attr_reader   :git, :currentLesson, :netrc, :status, :lessonName, :sentry
			attr_accessor :remote_name

			REPO_BELONGS_TO_US = [
				'commit-live-students'
			]

			def initialize()
				@git = setGit
				@netrc = CommitLive::NetrcInteractor.new()
				@currentLesson = CommitLive::Current.new
				@status = CommitLive::Status.new
				@lessonName = repo_name(remote: 'origin')
				@sentry = CommitLive::Sentry.new()
			end

			def commitAndPush
				checkRemote

				check_if_practice_lesson

				testCasePassed = currentLesson.getValue('test_case_pass')
				# Check if User passed test cases
				if testCasePassed
					# Push to User's Github
					addChanges
					commitChanges
					push

					pullRequestSubmitted = currentLesson.getValue('submitted_pull_request')
					if !pullRequestSubmitted
						# Create Pull Request
						createPullRequest
						update_lesson_status
					end

					puts "Done."
				else
					puts "It seems you have not passed all the test cases."
					puts "Please execute `clive test` before submitting your code!"
					exit
				end
			end

			private

			def check_if_practice_lesson
				currentLesson.getCurrentLesson(lessonName)
				lessonType = currentLesson.getValue('type')
				if lessonType == "PRACTICE"
					puts "This is a practice lesson. No need to submit anything."
					exit 1
				end
			end

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
				git.add(all: true)
			end

			def commitChanges
				begin
					git.commit('Done')
				rescue Git::GitExecuteError => e
					if e.message.match(/nothing to commit/)
						puts "It looks like you have no changes to commit."
						puts "Pushing previous commits if any."
					else
						puts 'Sorry, something went wrong. Please try again.'
						exit 1
					end
				end
			end

			def rollback_last_commit
				system("git reset HEAD~1")
			end

			def pull_changes
				begin
					Timeout::timeout(15) do
						git.pull
						puts "Now you will have to run `clive submit` again."
						exit 1
					end
				rescue Timeout::Error
					puts "Can't reach GitHub right now. Please try again."
					exit 1
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
					rollback_last_commit()
					if e.message.match(/(e.g., 'git pull ...')/)
						puts "There are some remote changes to pull."
						puts "Pulling the changes..."
						pull_changes
					else
						sentry.log_exception(e,
							{
								'event': 'pushing',
								'lesson_name' => lessonName,
							}
						)
					end
				rescue Timeout::Error
					puts "Can't reach GitHub right now. Please try again."
					exit 1
				end
			end

			def createPullRequest
				puts 'Creating Pull Request...'
				userGithub = CommitLive::Github.new()
				netrc.read(machine: 'ga-extra')
				username = netrc.login
				begin
					Timeout::timeout(45) do
						parentRepo = currentLesson.getValue('repo_url')
						pullRequest = userGithub.client.create_pull_request(
							parentRepo,
							'master',
							"#{username}:master",
							"PR by #{username}"
						)
					end
				rescue Octokit::Error => err
					if !err.message.match(/A pull request already exists/)
						sentry.log_exception(err,
							{
								'event': 'creating-pull-request',
								'lesson_name' => lessonName,
							}
						)
					end
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
				status.update('submitted_pull_request', lessonName)
			end
		end
	end
end
