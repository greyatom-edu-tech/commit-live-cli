module CommitLive
    class OptionsSanitizer
        attr_reader :args

        KNOWN_COMMANDS = [
            'test',
            'hello',
            'help',
            'version',
            '-v',
            '--version',
            'submit',
            'open',
            'reset',
            'setup'
        ]

        def initialize(args)
            @args = args
        end

        def sanitize!
            sanitizeTestArgs!
        end

        private

        def sanitizeTestArgs!
            if missingOrUnknownArgs?
                exitWithCannotUnderstand
            end
        end

        # Arg check methods
        def missingOrUnknownArgs?
            args.empty? || !KNOWN_COMMANDS.include?(args[0])
        end

        def exitWithCannotUnderstand
            puts "Sorry, I can't understand what you're trying to do. Type `clive help` for help."
            exit
        end
    end
end