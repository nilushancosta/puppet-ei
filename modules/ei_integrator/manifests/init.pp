# ----------------------------------------------------------------------------
#  Copyright (c) 2018 WSO2, Inc. http://www.wso2.org
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
# ----------------------------------------------------------------------------

# Class: ei_integrator
# Init class of EI Integrator default profile
class ei_integrator inherits ei_integrator::params {

  # Create wso2 group
  group { $user_group:
    ensure => present,
    gid    => $user_group_id,
    system => true,
  }

  # Create wso2 user
  user { $user:
    ensure => present,
    uid    => $user_id,
    gid    => $user_group_id,
    home   => "/home/${user}",
    system => true,
  }

  /*
  * Java Distribution
  */

  # Copy JDK distrubution path
  file { "${$lib_dir}":
    ensure => directory
  }

  # Copy JDK to Java distribution path
  file { "jdk-distribution":
    path   => "${java_home}.tar.gz",
    source => "puppet:///modules/common/${jdk_name}.tar.gz",
  }

  # Unzip distribution
  exec { "unpack-jdk":
    command => "tar -zxvf ${java_home}.tar.gz",
    path    => "/bin/",
    cwd     => "${lib_dir}",
    onlyif  => "/usr/bin/test ! -d ${java_home}",
  }

  /*
  * WSO2 Distribution
  */

  # Change the ownership of the installation directory to specified user & group
  file { [  "${products_dir}",
    "${products_dir}/${product}",
    "${products_dir}/${product}/${profile}",
    "${distribution_path}",
    "${distribution_path}/backup" ]:
    ensure => 'directory',
    owner   => $user,
    group   => $user_group,
    require => [ User[$user], Group[$user_group]],
    recurse => true
  }

  # Copy binary to distribution path
  file { "binary":
    path   => "$distribution_path/${product_binary}",
    owner  => $user,
    group  => $user_group,
    mode   => '0644',
    source => "puppet:///modules/${module_name}/${product_binary}",
  }

  # Stop the existing setup
  exec { "stop-server":
    command     => "kill -term $(cat ${install_path}/wso2carbon.pid)",
    path        => "/bin/",
    onlyif      => "/usr/bin/test -f ${install_path}/wso2carbon.pid",
    subscribe   => File["binary"],
    refreshonly => true,
  }

  # Wait for the server to stop
  exec { "wait":
    command     => "sleep 20",
    path        => "/bin/",
    onlyif      => "/usr/bin/test -d ${install_path}",
    subscribe   => File["binary"],
    refreshonly => true,
  }

  # Delete previous backup
  exec { "delete-backup":
    command     => "rm -rf ${distribution_path}/backup/${product}-${product_version}",
    path        => "/bin/",
    onlyif      => "/usr/bin/test -d ${distribution_path}/backup/${product}-${product_version}",
    subscribe   => File["binary"],
    refreshonly => true,
  }

  # Create backup
  exec { "create backup":
    command     => "mv ${install_path} ${distribution_path}/backup",
    path        => "/bin/",
    onlyif      => "/usr/bin/test -d ${install_path}",
    subscribe   => File["binary"],
    refreshonly => true,
  }

  # Install the "unzip" package
  package { 'unzip':
    ensure => installed,
  }

  # Unzip the binary and create setup
  exec { "unzip-update":
    command     => "unzip -qo ${product_binary}",
    path        => "/usr/bin/",
    user        => $user,
    cwd         => "${distribution_path}",
    onlyif      => "/usr/bin/test ! -d ${install_path}",
    subscribe   => File["binary"],
    refreshonly => true,
    require     => Package['unzip'],
  }

  # Copy wso2server.sh to installed directory
  file { "${install_path}/${start_script_template}":
    ensure  => file,
    owner   => $user,
    group   => $user_group,
    mode    => '0754',
    content => template("${module_name}/carbon-home/${start_script_template}.erb")
  }

  # Copy the unit file required to deploy the server as a service
  file { "/etc/systemd/system/${service_name}.service":
    ensure  => present,
    owner   => root,
    group   => root,
    mode    => '0754',
    content => template("${module_name}/${service_name}.service.erb"),
  }

  # Add agent specific file configurations
  # $config_file_list.each |$config_file| {
  #   exec { "sed -i -e 's/${config_file['key']}/${config_file['value']}/g' ${config_file['file']}":
  #     path => "/bin/",
  #   }
  # }

  /*
    Following script can be used to copy file to a given location.
    This will copy some_file to install_path -> repository.
    Note: Ensure that file is available in modules -> ei_integrator -> files
  */
  # file { "${install_path}/repository/some_file":
  #   owner  => $user,
  #   group  => $user_group,
  #   mode   => '0644',
  #   source => "puppet:///modules/${module_name}/some_file",
  # }
}
