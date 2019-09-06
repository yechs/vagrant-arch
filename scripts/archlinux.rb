# frozen_string_literal: true

class Archlinux
  def self.configure(config, settings)
    ENV['VAGRANT_DEFAULT_PROVIDER'] = settings['provider'] ||= 'virtualbox'

    # Configure Local Variable To Access Scripts From Remote Location
    # script_dir = File.dirname(__FILE__)

    # Configure the Box
    config.vm.box = settings['box'] ||= 'archlinux/archlinux'

    # Commented out since Arch is a rolling release
    # config.vm.box_version = settings['version'] ||= '>=0'

    # Configure Private Network
    config.vm.hostname = settings['hostname'] ||= 'archlinux'
    if settings['ip'] != 'dhcp'
      config.vm.network 'private_network',
        ip: settings['ip'] ||= '192.168.10.25'
    else
      config.vm.network 'private_network', type: 'dhcp'
    end

    # Configure Additional Network Settings (defined in config.yaml)
    if settings.key?('networks')
      settings['networks'].each do |net|
        config.vm.network net['type'],
          ip: net['ip'],
          bridge: net['bridge'] ||= nil,
          netmask: net['netmask'] ||= '255.255.255.0'
      end
    end

    # VirtualBox Customization Settings
    config.vm.provider 'virtualbox' do |v|
      v.name = settings['name'] ||= 'archlinux'
      v.memory = settings['memory'] ||= '2048'
      v.cpus = settings['cpus'] ||= '1'

      # Enable DNS proxy in NAT mode
      v.customize ['modifyvm', :id, '--natdnsproxy1', 'on']
      v.customize ['modifyvm',
                   :id,
                   '--natdnshostresolver1',
                   settings['natdnshostresolver'] ||= 'on']

      # OS Type
      v.customize ['modifyvm', :id, '--ostype', 'ArchLinux_64']

      # Headless vs GUI
      v.gui = true if settings.key?('gui') && settings['gui']
    end

    # Override Default SSH port
    if settings.key?('default_ssh_port')
      config.vm.network 'forwarded_port',
        guest: 22,
        host: settings['default_ssh_port'],
        auto_correct: false,
        id: 'ssh'
    end

    # Default Port Forwarding
    default_ports = {
      80 => 8000,
      443 => 44300,
      3306 => 33060,
      4040 => 4040,
      5432 => 54320,
      8025 => 8025,
      9600 => 9600,
      27017 => 27017
    }

    # Use Default Port Forwarding Unless Stated Otherwise
    unless settings.key?('default_ports') && settings['default_ports'] == false
      default_ports.each do |guest, host|
        # if custom port settings override default
        next if settings['ports'].any? { |mapping| mapping['guest'] == guest }

        config.vm.network 'forwarded_port',
          guest: guest,
          host: host,
          auto_correct: true
      end
    end

    # Add Custom Ports From Configuration
    if settings.key?('ports')
      settings['ports'].each do |port|
        config.vm.network 'forwarded_port',
          guest: port['guest'],
          host: port['host'],
          protocol: port['protocol'] ||= 'tcp',
          auto_correct: true
      end
    end

    # Configure SSH Keys
    # Add Public Key for SSH into the box
    if settings.include? 'pubkey'
      if File.exist? File.expand_path(settings['pubkey'])
        config.vm.provision 'shell' do |s|
          s.inline = 'echo $1 | grep -xq \"$1\" /home/vagrant/.ssh/authorized_keys || echo \"\n$1\" | tee -a /home/vagrant/.ssh/authorized_keys'
          s.args = [File.read(File.expand_path(settings['pubkey']))]
          # TODO: What's the first echo command for?
        end
      end
    end

    # Copy The SSH Private Keys To The Box
    # (for SSH into remote within the box)
    if settings.include? 'privkeys'
      if settings['privkeys'].to_s.length.zero?
        puts 'Check your configuration file, you have no private key(s) specified.'
        exit
      end
      settings['privkeys'].each do |key|
        if File.exist? File.expand_path(key)
          config.vm.provision 'shell' do |s|
            s.privileged = false
            s.inline = 'echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2'
            s.args = [
              File.read(File.expand_path(key)), key.split('/').last
            ]
          end
        else
          puts 'Check your configuration file, the path to your private key does not exist.'
          exit
        end
      end
    end

    # Copy User Files Over to VM
    if settings.include? 'copy'
      settings['copy'].each do |file|
        config.vm.provision 'file' do |f|
          f.source = File.expand_path(file['from'])
          f.destination = file['to'].chomp('/') + '/' + file['from'].split('/').last
        end
      end
    end

    # Register All Of The Configured Shared Folders
    if settings.include? 'folders'
      settings['folders'].each do |folder|
        if File.exist? File.expand_path(folder['map'])
          mount_options = []

          if folder['type'] == 'nfs'
            # Available on *nix & Mac OS Host
            # Check https://www.vagrantup.com/docs/synced-folders/nfs.html
            mount_options = folder['mount_options'] ? folder['mount_options'] : ['actimeo=1', 'nolock']
          elsif folder['type'] == 'smb'
            # Available on Windows & Mac OS Host
            # Check https://www.vagrantup.com/docs/synced-folders/smb.html
            mount_options = folder['mount_options'] ? folder['mount_options'] : ['vers=3.02', 'mfsymlinks']

            smb_creds = {
              smb_host: folder['smb_host'],
              smb_username: folder['smb_username'],
              smb_password: folder['smb_password']
            }
          end

          # merge with options
          options = (folder['options'] || {}).merge({ mount_options: mount_options }).merge(smb_creds || {})

          # Double-splat (**) operator only works with symbol keys, so convert
          options.keys.each{|k| options[k.to_sym] = options.delete(k) }

          config.vm.synced_folder folder['map'], folder['to'],
            type: folder['type'] ||= nil, # Defaults to Virtualbox if using
            **options

          # Bindfs support to fix shared folder (NFS) permission issue on Mac
          if folder['type'] == 'nfs' && Vagrant.has_plugin?('vagrant-bindfs')
            config.bindfs.bind_folder folder['to'], folder['to']
          end
        else
          config.vm.provision 'shell' do |s|
            s.inline = '>&2 echo \"Unable to mount one of your folders. Please check your folders in configuration files\"'
          end
        end
      end
    end
  end

  def self.backup_mysql(database, dir, config)
    # TODO
  end

  def self.backup_postgres(databse, dir, config)
    # TODO
  end
end
