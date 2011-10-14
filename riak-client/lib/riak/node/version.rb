require 'pathname'

module Riak
  class Node
    def version
      @version ||= configure_version
    end
    
    def configure_version
      versions = IO.read(base_dir + 'releases' + 'start_erl.data')
      versions.split(" ")[1]
    end

    def base_dir
      @base_dir ||= configure_base_dir
    end
    
    def configure_base_dir
      pattern = /^RUNNER_BASE_DIR=(.*)/
      lines = control_script.readlines.grep(pattern)
      if lines.empty?
        nil
      else
        line = lines.first
        case line
        when /^RUNNER_BASE_DIR=${RUNNER_SCRIPT_DIR%\/*}/
          source.parent
        else
          path = pattern.match(line)[1]
          Pathname.new(path).expand_path if File.directory?(path)
        end
      end
    end
  end
end
