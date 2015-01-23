stage { 'repo': }
stage { 'pre': }
Stage[repo] -> Stage[pre] -> Stage[main]

# Repos
class { 'epel': 
	stage => repo,
}

# Tools
class { 'concat::setup': 
	stage => pre
}
class { 'wget': 
	stage => pre
}

# Iptables
class iptables {
	package { "iptables":
		ensure => present
	}

	service { "iptables":
		require => Package["iptables"],
		hasstatus => true,
		status => "true",
		hasrestart => false,
	}

	file { "/etc/sysconfig/iptables":
		owner   => "root",
		group   => "root",
		mode    => 600,
		replace => true,
		ensure  => present,
		source  => "/vagrant/files/iptables.txt",
		require => Package["iptables"],
		notify  => Service["iptables"],
	}
}
class { 'iptables': }

class { 'nodejs':
  version => 'stable',
  stage => pre,
}

# MySQL
class { '::mysql::server':
  root_password    => '1234',
  override_options => { 'mysqld' => { 'max_connections' => '1024' } }
}

# Redis
class { 'redis': }

# Git
package { "git":
    ensure => "installed",
}

# ImageMagick
package { "ImageMagick":
    ensure => "installed",
}

# Ruby
$ruby_version = '2.2.0'
include rvm
rvm::system_user { vagrant: ; }
rvm_system_ruby {
  "ruby-$ruby_version":
     ensure      => 'present',
     default_use => true;
}

# Rails
rvm_gem { "$ruby_version/rails":
    ensure   => 'installed',
    require => [Rvm_system_ruby["ruby-$ruby_version"], Class['rvm']];
}
exec { "create-rails-app":
    user => 'vagrant',
    command => "/usr/local/rvm/bin/rvm $ruby_version exec rails new app",
    cwd     => '/home/vagrant',
    environment => ["HOME=/home/vagrant/"],
    creates => '/home/vagrant/app',
    require => Rvm_gem["$ruby_version/rails"],
	timeout => 0
}

# Nginx + Passenger
class nginx_passenger {
	$passenger_version = '4.0.58'
	rvm_gem { "$ruby_version/passenger":
		ensure 		=> $passenger_version,
		require		=> [Rvm_system_ruby["ruby-$ruby_version"], Class['rvm']],
	}
	package { "libcurl-devel":
		ensure   => 'installed',
	}
	exec { "passenger-install-nginx-module":
	    command => "/usr/local/rvm/bin/rvm $ruby_version exec passenger-install-nginx-module --auto --auto-download --prefix=/opt/nginx",
	    environment => [ 'HOME=/root', ],
	    path        => '/usr/bin:/usr/sbin:/bin',
	    require => [Package['libcurl-devel'], Rvm_gem["$ruby_version/passenger"]],
		timeout => 0
	} 
	file { "/opt/nginx/sites-enabled":
		ensure	=> directory,
		require => Exec["passenger-install-nginx-module"],
	}
	file { "/opt/nginx/conf/extras":
		ensure	=> directory,
		require => Exec["passenger-install-nginx-module"],
	}
	file { "/opt/nginx/conf/nginx.conf":
		content	=> template("/vagrant/templates/nginx.conf.erb"),
		require => Exec["passenger-install-nginx-module"],
		notify 	=> Service["nginx"]
	}
	file { "/opt/nginx/sites-enabled/app.conf":
		ensure  => present,
		source  => "/vagrant/files/nginx-vhost.txt",
		require => Exec["passenger-install-nginx-module"],
	}
	file { "/etc/rc.d/init.d/nginx":
		owner   => "root",
		group   => "root",
		mode    => "0611",
		replace => true,
		ensure  => present,
		source  => "/vagrant/files/nginx-service.txt",
		require	=> Exec["passenger-install-nginx-module"],
	}
	service { "nginx":
	  ensure 	=> running,
	  require => File['/etc/rc.d/init.d/nginx'],
	}
}
class { 'nginx_passenger': }