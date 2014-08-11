FROM ubuntu:14.04
MAINTAINER Joel Krauska

# Add multiverse
RUN echo "deb http://archive.ubuntu.com/ubuntu trusty main universe multiverse" > /etc/apt/sources.list
RUN apt-get update

# Add wget
RUN apt-get install -y wget

# Wget the trusty repo package from puppetlabs
RUN wget -q http://apt.puppetlabs.com/puppetlabs-release-trusty.deb -O /tmp/puppetlabs.deb
RUN dpkg -i /tmp/puppetlabs.deb
RUN apt-get update

# Install all the packages
RUN apt-get -y install puppetmaster-passenger puppet-dashboard puppetdb puppetdb-terminus redis-server supervisor openssh-server net-tools mysql-server

# Install needed redis and hiera
RUN gem install --no-ri --no-rdoc hiera hiera-puppet redis hiera-redis hiera-redis-backend

# Fix localhost
RUN echo "127.0.0.1 localhost puppet puppetdb puppetdb.local puppet.local" > /etc/hosts

# Make space for sshd
RUN mkdir /var/run/sshd

# Setup supervisor
ADD supervisor.conf /opt/supervisor.conf
ADD auth.conf /etc/puppet/auth.conf
ADD puppet.conf /etc/puppet/puppet.conf
ADD puppetdb.conf /etc/puppet/puppetdb.conf
RUN (sed -i 's/#host = localhost/host = 0.0.0.0/g' /etc/puppetdb/conf.d/jetty.ini)
ADD routes.yaml /etc/puppet/routes.yaml
ADD hiera.yaml /etc/hiera.yaml

RUN (start-stop-daemon --start -b --exec /usr/sbin/mysqld && sleep 5 ; echo "create database dashboard character set utf8;" | mysql -u root)
RUN (start-stop-daemon --start -b --exec /usr/sbin/mysqld && sleep 5 ; echo "create user dashboard@'localhost' identified by '1q2w3e4r5t';" | mysql -u root)
RUN (start-stop-daemon --start -b --exec /usr/sbin/mysqld && sleep 5 ; echo "grant all on dashboard.* to dashboard@'%';" | mysql -u root)
ADD database.yml /usr/share/puppet-dashboard/config/database.yml
RUN (start-stop-daemon --start -b --exec /usr/sbin/mysqld && cd /usr/share/puppet-dashboard && RAILS_ENV=production rake db:migrate)
RUN (sed -i 's/.*START.*/START=yes/g' /etc/default/puppet-dashboard)
RUN (sed -i 's/.*START.*/START=yes/g' /etc/default/puppet-dashboard-workers)

RUN mkdir /root/.ssh
# NOTE: change this key to your own
ADD sshkey.pub /root/.ssh/authorized_keys
RUN chown root:root /root/.ssh/authorized_keys
ADD run.sh /usr/local/bin/run

EXPOSE 22
EXPOSE 3000
EXPOSE 8080
EXPOSE 8081
EXPOSE 8140
CMD ["/usr/local/bin/run"]
