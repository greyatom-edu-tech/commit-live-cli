require "terminal-table"
require "commit-live/tests/strategy"

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
				system("nosetests --verbose --with-json --json-file=\"./.results.json\" > /dev/null")
				print_results
			end

			def print_results
				output["results"].each do |value|
					rows << [value["name"], value["type"]]
				end
				table = Terminal::Table.new :headings => ['Test Case', 'Status'], :rows => rows
				puts table
			end

			def results
				@output ||= Oj.load(File.read('.results.json'), mode: :compat)
			end

			def cleanup
				if File.exists?('.results.json')
					FileUtils.rm('.results.json')
				end
			end
		end
	end
end
