require "commit-live/lesson/current"
require "commit-live/netrc-interactor"
require "commit-live/github"

module CommitLive
  class Submit
    class GitHelper
      attr_reader   :git, :dummyUsername, :currentLesson, :netrc
      attr_accessor :remote_name

      REPO_BELONGS_TO_US = [
        'Rubygemtrial'
      ]

      def initialize()
        @git = setGit
        @dummyUsername = 'gitint'
        @netrc = CommitLive::NetrcInteractor.new()
        @currentLesson = CommitLive::Current.new
      end

      def commitAndPush
        checkRemote
        addChanges
        commitChanges

        push
        createPullRequest
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
        username = dummyUsername || netrc.login
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
        currentLesson.getCurrentLesson
        userGithub = CommitLive::Github.new()
        netrc.read
        username = dummyUsername || netrc.login
        begin
          Timeout::timeout(45) do
            parentRepo = currentLesson.getAttr('github_repo')
            pullRequest = userGithub.client.create_pull_request(parentRepo, 'master', "#{username}:master", "PR by #{username}")
            puts "Lesson submitted successfully!"
          end
        rescue Octokit::Error => err
          puts "Error while creating PR!"
          puts err
          exit
        rescue Timeout::Error
          puts "Please check your internet connection."
          exit
        end
      end
    end
  end
end
