require 'bundler/gem_helper'

def bundler_tasks(scm)
  case scm
    when :git
      Bundler::GemHelper.install_tasks
    when :hg
      Bundler::GemHelperMercurial.install_tasks
    else
      $stderr.puts "#{scm} scm not supported!"
      Kernel.exit!(-1)
  end
end

