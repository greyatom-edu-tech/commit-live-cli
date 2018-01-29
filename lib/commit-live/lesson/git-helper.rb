require "commit-live/lesson/current"
require "commit-live/lesson/status"
require "commit-live/netrc-interactor"
require "commit-live/github"
require "commit-live/sentry"

module CommitLive
	class Submit
		class GitHelper
			attr_reader   :git, :currentLesson, :netrc, :status, :lessonName, :sentry, :track_slug, :rootDir
			attr_accessor :remote_name

			HOME_DIR = File.expand_path("~")
			REPO_BELONGS_TO_US = [
				'commit-live-students'
			]

			def initialize(trackSlug)
				@track_slug = trackSlug
				@git = setGit
				@netrc = CommitLive::NetrcInteractor.new()
				@currentLesson = CommitLive::Current.new
				@status = CommitLive::Status.new
				@lessonName = repo_name(remote: 'origin')
				@sentry = CommitLive::Sentry.new()
				if File.exists?("#{HOME_DIR}/.ga-config")
					@rootDir = YAML.load(File.read("#{HOME_DIR}/.ga-config"))[:workspace]
				end
			end

			def commitAndPush
				checkRemote
				check_if_practice_lesson
				check_if_user_in_right_folder
				# Check if User passed test cases
				if is_test_case_passed
					# Push to User's Github
					addChanges
					commitChanges
					push

					if !is_submitted_pr
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

			def dir_path
				filePath = "#{title_slug}/"
				filePath += "#{test_slug}/" if is_project_assignment
				return filePath
			end

			def is_test_case_passed
				isTestCasesPassed = currentLesson.getValue('testCasesPassed')
				!isTestCasesPassed.nil? && isTestCasesPassed == 1
			end

			def test_slug
				currentLesson.getValue('testCase')
			end

			def is_project_assignment
				isProjectAssignment = currentLesson.getValue('isProjectAssignment')
				!isProjectAssignment.nil? && isProjectAssignment == 1
			end

			def is_submitted_pr
				isSubmittedPr = currentLesson.getValue('submittedPr')
				!isSubmittedPr.nil? && isSubmittedPr == 1
			end

			def is_project
				isProject = currentLesson.getValue('isProject')
				!isProject.nil? && isProject == 1
			end

			def is_practice
				lessonType = currentLesson.getValue('type')
				!lessonType.nil? && lessonType == "PRACTICE"
			end

			def repo_url
				currentLesson.getValue('repoUrl')
			end

			def title_slug
				currentLesson.getValue('titleSlug')
			end

			def check_if_practice_lesson
				currentLesson.getCurrentLesson(track_slug)
				if is_project || is_practice
					puts 'This is a Project. Go to individual assignments and follow intructions given on how to submit them.' if is_project
					puts 'This is a Practice Lesson. No need to submit your code.' if is_practice
					exit 1
				end
			end

			def check_if_user_in_right_folder
				dirname = File.basename(Dir.getwd)
				if dirname != title_slug
					table = Terminal::Table.new do |t|
						t.rows = [["cd ~/Workspace/code/#{title_slug}/"]]
					end
					puts "It seems that you are in the wrong directory."
					puts "Use the following command to go there"
					puts table
					puts "Then use the `clive submit <track-slug>` command"
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
					if e.message.match(/'git pull ...'/)
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
				github = CommitLive::Github.new()
				github.post(repo_url)
			end

			def repo_name(remote: remote_name)
				url = git.remote(remote).url
				url.match(/^.+[\w-]+\/(.*?)(?:\.git)?$/)[1]
			end

			def update_lesson_status
				file_path = "#{rootDir}/#{dir_path}/build.py"
				status.update('submittedPr', track_slug, true, {}, file_path)
			end
		end
	end
end
