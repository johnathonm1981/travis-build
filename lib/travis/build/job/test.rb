require 'active_support/inflector/methods'

# # rake and fileutils might be mixed into the global namespace, defining :install
# class Hashr; undef :install; end

module Travis
  class Build
    module Job
      class Test
        autoload :Clojure, 'travis/build/job/test/clojure'
        autoload :Erlang,  'travis/build/job/test/erlang'
        autoload :Nodejs,  'travis/build/job/test/nodejs'
        autoload :Php,     'travis/build/job/test/php'
        autoload :Ruby,    'travis/build/job/test/ruby'

        extend Assertions

        class << self
          def by_lang(lang)
            lang = lang || 'ruby'
            args = [ActiveSupport::Inflector.camelize(lang.gsub('.', '').downcase)]
            args << false if Kernel.method(:const_get).arity == -1
            Job::Test.const_get(*args) rescue Job::Test::Ruby
          end
        end

        attr_reader :shell, :commit, :config, :commands

        def initialize(shell, commit, config)
          @shell = shell
          @commit = commit
          @config = config
          @commands = %w(before_install install before_script script after_script)
        end

        def run
          { :status => perform ? 0 : 1 }
        end

        protected

          def perform
            chdir
            export
            checkout
            setup if respond_to?(:setup)
            run_commands
          rescue AssertionFailed => e
            false
          end

          def chdir
            shell.chdir('~/builds')
          end

          def export
            Array(config.env).each do |env|
              shell.export(*env.split('=')) unless env.empty?
            end if config.env
          end

          def checkout
            commit.checkout
          end
          assert :checkout

          def run_commands
            commands.each do |type|
              script = config[type] || (respond_to?(type, true) ? send(type) : nil)
              return false if script && !run_command(script, :timeout => type.to_sym)
            end && true
          end

          def run_command(script, options = {})
            Array(script).each do |script|
              return false unless shell.execute(script, options)
            end && true
          end
      end
    end
  end
end