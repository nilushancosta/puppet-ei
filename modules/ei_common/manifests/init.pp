#----------------------------------------------------------------------------
#  Copyright (c) 2019 WSO2, Inc. http://www.wso2.org
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#----------------------------------------------------------------------------

class ei_common inherits ei_common::params {

  include '::ei_common::service'

  # Install system packages
  package { $packages:
    ensure => installed
  }

  # Create wso2 group
  group { $user_group:
    ensure => present,
    gid    => $user_group_id,
    system => true,
  }

  # Create wso2 user
  user { $user:
    ensure  => present,
    uid     => $user_id,
    gid     => $user_group_id,
    home    => "/home/${user}",
    system  => true,
    require => Group["${user_group}"]
  }

  /*
  * Java Distribution
  */

  # Copy JDK to Java distribution path
  file { "jdk-distribution":
    path   => "${java_home}.tar.gz",
    source => "puppet:///modules/${module_name}/jdk/${jdk_name}.tar.gz",
  }

  # Unzip distribution
  exec { "unpack-jdk":
    command     => "tar -zxvf ${java_home}.tar.gz",
    path        => "/bin/",
    cwd         => "${java_dir}",
    onlyif      => "/usr/bin/test ! -d ${java_home}",
    subscribe   => File["jdk-distribution"],
    refreshonly => true
  }

  # Create symlink to Java binary
  file { "${java_symlink}":
    ensure  => "link",
    target  => "${java_home}",
    require => Exec["unpack-jdk"]
  }

  /*
  * WSO2 Distribution
  */

  file { ["${product_dir}", "${pack_dir}"]:
    ensure  => directory,
    owner   => $user,
    group   => $user_group,
    require => [ User["${user}"], Group["${user_group}"] ]
  }

  # Copy binary to distribution path
  file { "wso2-binary":
    path    => "${pack_dir}/${product_binary}",
    owner   => $user,
    group   => $user_group,
    mode    => '0644',
    source  => "puppet:///modules/${module_name}/packs/${product_binary}",
    require => File["${product_dir}", "${pack_dir}"]
  }

  # Stop the existing setup
  exec { "stop-server":
    command     => "systemctl stop ${wso2_service_name}",
    path        => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ],
    tries       => $try_count,
    try_sleep   => $try_sleep,
    onlyif      => "/usr/bin/test -f /etc/systemd/system/${wso2_service_name}.service",
    subscribe   => File["wso2-binary"],
    refreshonly => true,
  }

  # Delete existing setup
  exec { "detele-pack":
    command     => "rm -rf ${carbon_home}",
    path        => "/bin/",
    onlyif      => "/usr/bin/test -d ${carbon_home}",
    subscribe   => File["wso2-binary"],
    refreshonly => true,
  }

  # Unzip the binary and create setup
  exec { "unzip-update":
    command     => "unzip ${product_binary} -d ${product_dir}",
    path        => "/usr/bin/",
    user        => $user,
    group       => $user_group,
    cwd         => "${pack_dir}",
    subscribe   => File["wso2-binary"],
    refreshonly => true,
  }

  # Copy the unit file required to deploy the server as a service
  file { "/etc/systemd/system/${wso2_service_name}.service":
    ensure  => present,
    owner   => root,
    group   => root,
    mode    => '0754',
    content => template("${module_name}/carbon.service.erb"),
  }

  exec { 'systemctl daemon-reload':
    path    =>  '/bin/:/sbin/:/usr/bin/:/usr/sbin/',
    subscribe => File["/etc/systemd/system/${wso2_service_name}.service"],
    refreshonly => true,
  }
}
