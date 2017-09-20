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
				system("nosetests --verbose --with-json --json-file=\"./.results.json\" > /dev/null 2>&1")
			end

			def print_results
				if File.exists?('.results.json')
					rows = []
					totalPassed = 0
					totalFailed = 0
					test_results = results
					columns = ['Test Case', 'Status']
					test_results["results"].each do |value|
						newRow = [value["name"], value["type"]]
						isErrorOrFail = value['type'] == 'failure' || value['type'] == 'error'
						totalFailed += 1 if isErrorOrFail
						newRow << value['message'] if isErrorOrFail
						totalPassed += 1 if value['type'] == 'success'
						rows << newRow
					end
					if totalFailed > 0
						columns << 'Message'
					end
					table = Terminal::Table.new do |t|
						t.headings = columns
						t.rows = rows
						t.style = { :all_separators => true }
					end
					puts table
					puts "Total Passed: #{totalPassed}"
					puts "Total Failed: #{totalFailed}"
				end
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
