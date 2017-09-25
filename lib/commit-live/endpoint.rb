module CommitLive
	class Endpoint
		END_POINTS = {
			"PROD" => 'https://api.commit.live', 
			"DEV" => 'http://api.greyatom.com', 
			"LOCAL" => 'http://greyatom-service-dev-env.ap-south-1.elasticbeanstalk.com'
		}
		def get()
			return END_POINTS[getEnv()]
		end
		def getEnv()
			env = ENV["COMMIT_LIVE_ENV"]
			if !env.nil?
				return env
			end
			return "PROD"
		end
	end
end
