require "spec_helper"
require 'bundler/gem_tasks'

describe 'gem_tasks tasks' do
  describe 'bundler_tasks' do
    it 'should call Bundler::GemHelper.install_tasks with :git as parameter' do
      Bundler::GemHelper.should_receive(:install_tasks).once
      Bundler::GemHelperMercurial.should_not_receive(:install_tasks)
      bundler_tasks(:git)
    end
    it 'should call Bundler::GemHelperMercurial.install_tasks with :hg as parameter' do
      Bundler::GemHelper.should_not_receive(:install_tasks)
      Bundler::GemHelperMercurial.should_receive(:install_tasks).once
      bundler_tasks(:hg)
    end
    it 'should exit with some error with wrong scm' do
      $stderr.should_receive(:puts).once
      Kernel.should_receive(:exit!).with(-1).once
      Bundler::GemHelper.should_not_receive(:install_tasks)
      Bundler::GemHelperMercurial.should_not_receive(:install_tasks)
      bundler_tasks(:i_am_not_a_scm)
    end
  end

end