class Archlinux
  def self.configure(config, settings)

    ENV['VAGRANT_DEFAULT_PROVIDER'] = settings['provider'] ||= 'virtualbox'

    # Configure Local Variable To Access Scripts From Remote Location
    script_dir = File.dirname(__FILE__)

    # Configure the Box
    config.vm.box = settings['box'] ||= 'archlinux/archlinux'

    # Commented out since Arch is a rolling release
    # config.vm.box_version = settings['version'] ||= '>=0'

    # Configure Private Network
    config.vm.hostname = settings['hostname'] ||= 'archlinux'
    if settings['ip'] != 'dhcp'
      config.vm.network "private_network", ip: settings['ip'] ||= '192.168.10.25'
    else
      config.vm.network "private_network", type: "dhcp"
    end

    # Configure Additional Network Settings (defined in config.yaml)
    if settings.has_key?('networks')
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
      v.customize ['modifyvm', :id, '--natdnshostresolver1', settings['natdnshostresolver'] ||= 'on']

      # OS Type
      v.customize ['modifyvm', :id, '--ostype', 'ArchLinux_64']

      # Headless vs GUI
      if settings.has_key?('gui') && settings['gui']
        v.gui = true
      end

  end

  def self.backup_mysql(database, dir, config)
    # TO-DO
  end

  def self.backup_postgres(databse, dir, config)
    # TO-DO
  end
end
