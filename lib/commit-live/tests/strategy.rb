module CommitLive
  class Strategy

    def check_dependencies
    end

    def configure
    end

    def run
      raise NotImplementedError, 'you must implement how this strategy runs its tests'
    end
    
  end
end
