require 'test_helper'

STDOUT.sync = true

class WorkerBuildTest < Test::Unit::TestCase
  include Travis

  attr_reader :now, :shell, :worker, :job, :reporter

  def setup
    super

    config = { 'test' => { 'reporter' => { 'http' => { 'url' => 'http://sven:1234567890@travis-ci.org' } } } }
    YAML.stubs(:load_file).with('config.yml').returns(config)

    @now = Time.now
    Time.stubs(:now).returns(now)

    Travis::Worker.shell = Mock::Shell.new

    @worker   = Worker.new('meta_id', INCOMING_PAYLOADS['build:gem-release'])
    @job      = worker.job
    @reporter = worker.reporter

    class << reporter # stubbing doesn't seem to work in a separate thread?
      def connection(*)
        Mock::HttpRequest.new
      end
    end

  end

  test 'running a build' do
    job.expects(:build!).with { job.send(:update, :log => 'log'); true }.returns(true)
    worker.work!

    assert_messages [
      [:post, '/builds/1',     { :build => { :started_at => now } }],
      [:post, '/builds/1/log', { :build => { :log => 'log' } }],
      [:post, '/builds/1/log', { :build => { :log => "\nDone. Build script exited with: 0\n" } }],
      [:post, '/builds/1',     { :build => { :log => "log\nDone. Build script exited with: 0\n", :status => 0, :finished_at => now } }],
    ]
  end

  protected

    def assert_messages(messages)
      messages.each_with_index do |message, i|
        message[2].merge!(:_method=>:put, :msg_id => i + 1)
        assert_equal message, Mock::HttpRequest.requests[i]
      end
    end
end
