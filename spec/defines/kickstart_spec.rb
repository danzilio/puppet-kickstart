require 'spec_helper'

describe 'kickstart' do
  let(:title) { '/tmp/kickstart.cfg' }
  let(:commands) do
    {
      'install' => true,
      'text' => true,
      'reboot' => true,
      'skipx' => true,
      'url' => '--url http://mirror.centos.org/centos/6/os/x86_64',
      'lang' => 'en_US.UTF-8',
      'keyboard' => 'us',
      'network' => '--device eth0 --bootproto dhcp',
      'rootpw' => 'test1234',
      'firewall' => '--disabled',
      'selinux' => '--permissive',
      'authconfig' => '--enableshadow --enablemd5',
      'timezone' => 'UTC',
      'bootloader' => '--location mbr',
    }
  end
  let(:partition_configuration) do
    {
      'zerombr' => 'yes',
      'clearpart' => '--all --initlabel',
      'part' => [
        '/boot --fstype ext3 --size 250',
        'pv.2 --size 5000 --grow',
      ],
      'volgroup' => 'VolGroup00 --pesize 32768 pv.2',
      'logvol' => [
        '/ --fstype ext4 --name LogVol00 --vgname VolGroup00 --size 1024 --grow',
        'swap --fstype swap --name LogVol01 --vgname VolGroup00 --size 256 --grow --maxsize 512'
      ]
    }
  end
  let(:packages) {[ '@base' ]}
  let(:fragments) do
    {
      'post' => ["#{fixture_path}/templates/post.erb"]
    }
  end
  let(:fragment_variables) {{ 'kind' => 'post' }}
  let(:repos) do
    {
      'base' => {
        'baseurl' => 'http://mirror.centos.org/centos/6/os/x86_64'
      }
    }
  end
  let(:addons) do
    {
      'my_addon_name --arg1 --arg2="value2"' => ['example1','example2','example3'],
      'my_other_addon' => '',
    }
  end
  let(:ensure) { 'present' }
  let(:params) do
    {
      :partition_configuration => partition_configuration,
      :commands => commands,
      :packages => packages,
      :fragments => fragments,
      :fragment_variables => fragment_variables,
      :repos => repos,
      :addons => addons,
    }
  end

  context 'when passing valid data to all parameters' do
    it { is_expected.to compile }

    it 'should contain all of the repos' do
      repos.keys.each do |repo|
        is_expected.to contain_file(title).with_content %r{^repo --name #{repo}}
      end
    end

    it 'should contain all of the commands' do
      commands.keys.each do |command|
        is_expected.to contain_file(title).with_content %r{^#{command}}
      end
    end

    it 'should contain all of the partition commands' do
      partition_configuration.keys.each do |command|
        is_expected.to contain_file(title).with_content %r{^#{command}}
      end
    end

    it 'should contain a valid packages section' do
      is_expected.to contain_file(title).with_content /^%packages$\s+(^\S+$)\s+^%end$/
    end

    it 'should contain a valid post section' do
      is_expected.to contain_file(title).with_content /^%post$\s(^.*$)\s^%end$/m
      is_expected.to contain_file(title).with_content /^THIS IS A post SCRIPT!$/
    end

    it 'should contain a valid addon section' do
      addons.keys.each do |addon|
        is_expected.to contain_file(title).with_content %r{^%addon #{addon}}
      end
    end
  end

  context 'when handling packages hash with options' do
    let(:packages) { {'options' => '--nobase --ignoremissing', 'package_list' => [ '@core', 'authconfig', 'system-config-firewall-base']} }

    it { is_expected.to compile }
    it { is_expected.to contain_file(title).with_content /^%packages --nobase --ignoremissing$\s+(^[\S\s]+$)\s+^%end$/ }
  end

  context 'when handling packages hash without options' do
    let(:packages) { {'package_list' => [ '@core', 'authconfig', 'system-config-firewall-base']} }

    it { is_expected.to compile }
    it { is_expected.to contain_file(title).with_content /^%packages$\s+(^[\S\s]+$)\s+^%end$/ }
  end

  context 'when packages is not an array or hash' do
    let(:packages) { 'package_list' }

    it { is_expected.not_to compile }
  end

  context 'handling false values' do
    let(:falsey_commands) {{ 'foo' => false, 'bar' => 'false' }}
    let(:params) {{ :commands => falsey_commands, :fail_on_unsupported_commands => false }}

    it { is_expected.to contain_file(title).without_content /foo/ }
    it { is_expected.to contain_file(title).with_content /^bar false/ }
  end

  context 'with only the commands parameter defined' do
    let(:params) {{ :commands => commands }}

    it { is_expected.to compile }
    it { is_expected.to contain_file(title).with_content /Command Section/ }
    it { is_expected.to contain_file(title).without_content /Packages Section/ }
    it { is_expected.to contain_file(title).without_content /Partition Configuration/ }
    it { is_expected.to contain_file(title).without_content /^%post/ }
  end

  context 'when passing an invalid kickstart Command' do
    let(:params) {{:commands => {'foo' => 'bar'}}}

    it { is_expected.not_to compile }
    it { is_expected.to raise_error Puppet::Error, /Unsupported Kickstart commands/ }
  end

  context 'when multiple fragments for pre/post are provided' do
    let(:fragment_variables) {{ 'kind' => 'post', 'other_kind' => 'pre', 'opts' => 'nochroot' }}
    let(:fragments) do
      {
        'pre' => ["#{fixture_path}/templates/pre.erb"],
        'post --nochroot' => ["#{fixture_path}/templates/post_opts.erb"],
        'post' => ["#{fixture_path}/templates/post.erb"]
      }
    end

    it { is_expected.to compile }
    it { is_expected.to contain_file(title).with_content /^%pre$\s(^.*$)\s^%end$\s^%post --nochroot$\s(^.*$)\s^%end$\s^%post$\s(^.*$)\s^%end$/m }
  end

  context 'when ensure is not valid' do
    let(:params) {{:ensure => 'delete', :commands => commands}}

    it { is_expected.not_to compile }
    it { is_expected.to raise_error Puppet::Error, /Invalid value for ensure. Must be 'present' or 'absent'/ }
  end

  context 'when marking configuration as absent' do
    let(:params) {{:ensure => 'absent', :commands => commands}}

    it { is_expected.to compile }
    it { is_expected.to contain_file(title).with_ensure('absent') }
  end

end
