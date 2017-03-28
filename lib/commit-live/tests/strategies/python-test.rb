require 'commit-live/tests/strategy'

module CommitLive
	module Strategies
		class PythonUnittest < CommitLive::Strategy
			def detect
				files.any? {|f| f.match(/.*.py$/) }
			end

			def files
				@files ||= Dir.entries('.')
			end

			def run
				system("nosetests")
			end
		end
	end
end
