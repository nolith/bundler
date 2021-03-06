require "strscan"

# Some versions of the Bundler 1.1 RC series introduced corrupted
# lockfiles. There were two major problems:
#
# * multiple copies of the same GIT section appeared in the lockfile
# * when this happened, those sections got multiple copies of gems
#   in those sections.
#
# As a result, Bundler 1.1 contains code that fixes the earlier
# corruption. We will remove this fix-up code in Bundler 1.2.

module Bundler
  class LockfileParser
    attr_reader :sources, :dependencies, :specs, :platforms

    def initialize(lockfile)
      @platforms    = []
      @sources      = []
      @dependencies = []
      @specs        = []
      @state        = :source

      lockfile.split(/(\r?\n)+/).each do |line|
        if line == "DEPENDENCIES"
          @state = :dependency
        elsif line == "PLATFORMS"
          @state = :platform
        else
          send("parse_#{@state}", line)
        end
      end
    end

  private

    TYPES = {
      "HG"   => Bundler::Source::Mercurial,
      "GIT"  => Bundler::Source::Git,
      "GEM"  => Bundler::Source::Rubygems,
      "PATH" => Bundler::Source::Path
    }

    def parse_source(line)
      case line
      when "HG", "GIT", "GEM", "PATH"
        @current_source = nil
        @opts, @type = {}, line
      when "  specs:"
        @current_source = TYPES[@type].from_lock(@opts)

        # Strip out duplicate GIT sections
        if @sources.include?(@current_source) && @current_source.is_a?(Bundler::Source::Git)
          @current_source = @sources.find { |s| s == @current_source }
        end

        @sources << @current_source
      when /^  ([a-z]+): (.*)$/i
        value = $2
        value = true if value == "true"
        value = false if value == "false"

        key = $1

        if @opts[key]
          @opts[key] = Array(@opts[key])
          @opts[key] << value
        else
          @opts[key] = value
        end
      else
        parse_spec(line)
      end
    end

    NAME_VERSION = '(?! )(.*?)(?: \(([^-]*)(?:-(.*))?\))?'

    def parse_dependency(line)
      if line =~ %r{^ {2}#{NAME_VERSION}(!)?$}
        name, version, pinned = $1, $2, $4
        version = version.split(",").map { |d| d.strip } if version

        dep = Bundler::Dependency.new(name, version)

        if pinned && dep.name != 'bundler'
          spec = @specs.find { |s| s.name == dep.name }
          dep.source = spec.source if spec

          # Path sources need to know what the default name / version
          # to use in the case that there are no gemspecs present. A fake
          # gemspec is created based on the version set on the dependency
          # TODO: Use the version from the spec instead of from the dependency
          if version && version.size == 1 && version.first =~ /^\s*= (.+)\s*$/ && dep.source.is_a?(Bundler::Source::Path)
            dep.source.name    = name
            dep.source.version = $1
          end
        end

        @dependencies << dep
      end
    end

    def parse_spec(line)
      if line =~ %r{^ {4}#{NAME_VERSION}$}
        name, version = $1, Gem::Version.new($2)
        platform = $3 ? Gem::Platform.new($3) : Gem::Platform::RUBY
        @current_spec = LazySpecification.new(name, version, platform)
        @current_spec.source = @current_source

        # Avoid introducing multiple copies of the same spec (caused by
        # duplicate GIT sections)
        @specs << @current_spec unless @specs.include?(@current_spec)
      elsif line =~ %r{^ {6}#{NAME_VERSION}$}
        name, version = $1, $2
        version = version.split(',').map { |d| d.strip } if version
        dep = Gem::Dependency.new(name, version)
        @current_spec.dependencies << dep
      end
    end

    def parse_platform(line)
      if line =~ /^  (.*)$/
        @platforms << Gem::Platform.new($1)
      end
    end

  end
end
