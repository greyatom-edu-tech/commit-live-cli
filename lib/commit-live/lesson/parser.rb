module CommitLive
	module Puzzle
		class Parser
			attr_reader :name

			def initialize(name)
				@name = name
			end

			def parse!
				if name.chars.include?(' ')
					slugify_name!
				else
					name.strip
				end
			end

			private

			def slugify_name!
				name.gsub(' ', '-').strip
			end
		end
	end
end
