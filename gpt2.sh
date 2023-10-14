#!/bin/bash

# Ensure Vagrant and VirtualBox are installed
if ! command -v vagrant > /dev/null || ! command -v vboxmanage > /dev/null; then
  echo "Vagrant and VirtualBox are not installed. Installing..."
  # You can add installation commands here for your specific OS.
  # For Ubuntu, you can use the following commands:
  # sudo apt-get update
  # sudo apt-get install -y vagrant virtualbox
fi

# Create Vagrantfile if not already present
if [ ! -f "Vagrantfile" ]; then
  echo "Creating Vagrantfile..."
  # You can copy and paste your Vagrantfile content here.
  # Make sure the content is enclosed within EOF markers as shown below.
  cat > Vagrantfile <<EOF
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Define the Ubuntu 22.04 box for master
  config.vm.define "master" do |master|
    # ... (your master configuration)
    master.vm.box = "ubuntu/focal64"
    master.vm.hostname = "master"
    master.vm.network "private_network", type: "static", ip: "169.254.194.192/16"
    master.vm.provider "virtualbox" do |vb|
      vb.memory = 1024 # 1GB RAM
      vb.cpus = 1
    end
    
    # Provisioning script for the master node
    master.vm.provision "shell", inline: <<-SHELL
      # Create the 'altschool' user
      useradd -m -G sudo -s /bin/bash altschool

      # set a default password for user
      echo "altschool:085200" | chpasswd
    
      # Grant 'altschool' user root privileges
      echo "altschool ALL=(ALL:ALL) ALL" >> /etc/sudoers
    
      # Generate an SSH key pair for 'altschool' user (without a passphrase)
      sudo -u altschool ssh-keygen -t rsa -N "" -f /home/altschool/.ssh/id_rsa
    
      # Install Apache, MySQL, PHP, and other required packages
      sudo apt-get update
      sudo apt-get -y upgrade
      DEBIAN_FRONTEND=noninteractive sudo apt-get -y install apache2 mysql-server php libapache2-mod-php php-mysql
    
      # Start and enable Apache on boot
      systemctl start apache2
      systemctl enable apache2
    
      # Secure MySQL installation and initialize it with a default user and password
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password 085200'
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password 085200'
      apt-get -y install mysql-server
    
      # Create a sample PHP file for validation
      echo "<?php phpinfo(); ?>" > /var/www/html/info.php

      # Display an overview of the Linux process management, showcasing currently running processes on startup
      ps aux
    SHELL
  end

  # Define the Ubuntu 22.04 box for the slave node
  config.vm.define "slave" do |slave|
    # ... (your slave configuration)
    slave.vm.box = "ubuntu/focal64"
    slave.vm.hostname = "slave"
    slave.vm.network "private_network", type: "static", ip: "192.168.56.61"
    slave.vm.provider "virtualbox" do |vb|
      vb.memory = 1024 # 1GB RAM
      vb.cpus = 1
    end
    
    # Provisioning script for the slave node
    slave.vm.provision "shell", inline: <<-SHELL
      # Create the 'altschool' user
      useradd -m -G sudo -s /bin/bash altschool

      # set a default password for user
      echo "altschool:085200" | chpasswd
    
      # Grant 'altschool' user root privileges
      echo "altschool ALL=(ALL:ALL) ALL" >> /etc/sudoers
    
      # Generate an SSH key pair for 'altschool' user (without a passphrase)
      sudo -u altschool ssh-keygen -t rsa -N "" -f /home/altschool/.ssh/id_rsa
    
      # Allow SSH key-based authentication for 'altschool' user
      mkdir -p /home/altschool/.ssh
      cat /home/altschool/.ssh/id_rsa.pub >> /home/altschool/.ssh/authorized_keys
      chmod 700 /home/altschool/.ssh
      chmod 600 /home/altschool/.ssh/authorized_keys
      chown -R altschool:altschool /home/altschool/.ssh
    
      # Create the /mnt/altschool/slave directory
      mkdir -p /mnt/altschool/slave
    
      # Transfer data from the Master node to the Slave node
      sudo -u altschool scp -o StrictHostKeyChecking=no /mnt/altschool/master_data.txt altschool@192.168.56.61:/mnt/altschool/slave/
    
      # Install Apache, MySQL, PHP, and other required packages
      apt-get update
      apt-get -y upgrade
      DEBIAN_FRONTEND=noninteractive apt-get -y install apache2 mysql-server php libapache2-mod-php php-mysql
    
      # Start and enable Apache on boot
      systemctl start apache2
      systemctl enable apache2
    
      # Secure MySQL installation and initialize it with a default user and password
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password 085200'
      sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password 085200'
      apt-get -y install mysql-server
    
      # Create a sample PHP file for validation
      echo "<?php phpinfo(); ?>" > /var/www/html/info.php
    SHELL
  end

  # Define the Ubuntu 20.04 box for the load balancer (Nginx)
  config.vm.define "loadbalancer" do |lb|
    # ... (your load balancer configuration)
    lb.vm.box = "bento/ubuntu-22.04"
    lb.vm.network "private_network", type: "static", ip: "169.254.194.192/16"
    lb.vm.provider "virtualbox" do |vb|
      vb.memory = 1024 # 1GB RAM
      vb.cpus = 1
    end

    # Provisioning script for the load balancer node
    lb.vm.provision "shell", inline: <<-SHELL
      # Update package lists for upgrades and new package installations
      apt-get update

      # Install Nginx
      apt-get install -y nginx

      # Remove the default Nginx configuration file
      rm /etc/nginx/sites-enabled/default

      # Create a new Nginx configuration file
      cat > /etc/nginx/sites-enabled/load_balancer <<EOF
      upstream backend {
      server 169.254.194.192/16;
      server 169.254.194.192/16;

      }

      server {
        listen 80;

        location / {
          proxy_pass http://backend;
        }
      }
    EOF

      # Restart Nginx to apply the changes
      systemctl restart nginx
    SHELL

  end
end
EOF
fi

# Start Vagrant environment
echo "Starting Vagrant environment..."
vagrant up

# Display a message indicating success
echo "Vagrant environment is up and running."
