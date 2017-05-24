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
				system("nosetests --verbose --with-json --json-file=\"./.results.json\"")
			end

			def results
				@output ||= Oj.load(File.read('.results.json'), mode: :compat)
			end

			def cleanup
				FileUtils.rm('.results.json')
			end
		end
	end
end
