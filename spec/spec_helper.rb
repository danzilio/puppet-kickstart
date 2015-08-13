require 'puppetlabs_spec_helper/module_spec_helper'

def fixture_path
  File.expand_path(File.join(__FILE__, '..', 'fixtures'))
end

RSpec.configure do |c|
  c.formatter = 'documentation'

  if ENV['PUPPET_DEBUG']
    Puppet::Util::Log.level = :debug
    Puppet::Util::Log.newdestination(:console)
  end

  if ENV['PARSER'] == 'future'
    c.parser = 'future'
  end
end
