# Use Salt Cloud Map Files to Deploy Application Servers and a Reverse Proxy.

### In this tutorial we'll show you how to define your application in a Salt Cloud map file, including the use of custom grains to assign roles to your servers and dynamically configure a reverse proxy. At the end of this tutorial, you will have:

* Two basic app servers
* An nginx reverse proxy with a dynamically-built configuration

## Prerequisites
You'll need to have Salt Cloud configured on your machine.  [Automated Provisioning of DigitalOcean Cloud Servers with Salt Cloud on Ubuntu 12.04](https://www.digitalocean.com/community/tutorials/automated-provisioning-of-digitalocean-cloud-servers-with-salt-cloud-on-ubuntu-12-04) can help get you set up. Note that while previous articles focus on Ubuntu, this tutorial is applicable to most major Linux distros (Debian-and-RHEL family).

**NOTE**: Your Salt Master that you use for this tutorial will need to be accessible to the minions you will create. This means that if you're on your home machine behind a NAT'd network, you'll need to create a droplet (or some other publicly-accessible machine) and use that for your Salt Master.

## Map file locations
Recall that, in Salt Cloud, you need to define at least one `provider` and at least one `profile`. Those are defined at the following locations:

* `/etc/salt/cloud.providers.d` -- cloud providers (e.g. digitalocean)
* `/etc/salt/cloud.profiles.d` -- cloud profiles (e.g. ubuntu_2GB)

Assuming you followed the previous tutorial on setting up Salt Cloud, you should have the following in `/etc/salt/cloud.providers.d/digital_ocean.conf:

~~~~
do:
  provider: digital_ocean
  
  # Digital Ocean account keys
  client_key: YourClientIDCopiedFromControlPanel
  api_key: YourAPIKeyCopiedFromControlPanel
  ssh_key_name: digital-ocean-salt-cloud.pub
  
  # Directory & file name on your Salt master
  ssh_key_file: /keys/digital-ocean-salt-cloud
~~~~

And you should have something like the following in `/etc/salt/cloud.profiles.d/digital_ocean.conf`:

~~~~
ubuntu_512MB_ny2:
  provider: do
  image: Ubuntu 12.04.4 x64
  size: 512MB
#  script: Optional Deploy Script Argument
  location: New York 2
  private_networking: True

ubuntu_1GB_ny2:
  provider: do
  image: Ubuntu 12.04.4 x64
  size: 1GB
#  script: Optional Deploy Script Argument
  location: New York 2
  private_networking: True
~~~~

## Map Files - The Beginning
Going with the above profiles, let's say you want two 1GB app servers fronted by a single 512MB reverse proxy. You can place mapfiles wherever is best for you but for this demonstration, let's make a mapfile in `/etc/salt/mapfiles/do-app-with-rproxy.conf` and put the following in it:

~~~~
ubuntu_512MB_ny2:
  - nginx-rproxy
  
ubuntu_1GB_ny2:
  - appserver-01
  - appserver-02
~~~~

That's it! That's about as simple as a Map File gets. Go ahead and try it out with:

~~~~
salt-cloud -P -m /etc/salt/mapfiles/do-app-with-rproxy.conf
~~~~

The `-P` is for 'parallel`, telling Salt Cloud to launch all three VMs at the same time (as oppossed to one after the other).

Once you've successfully created the VMs in your map file, deleting them is just as easy:
~~~~
salt-cloud -d -m /etc/salt/mapfiles/do-app-with-rproxy.conf
~~~~

Be sure to use that one with caution, though! It will delete *all* the VMs specified in that map file.

## Map Files - Moar Cloud
That's nice and all, but a shell script can make a set of VMs. What we need is to define the footprint of our application. Let's go back to our map file and add the following:

~~~~
ubuntu_512MB_ny2:
  - nginx-rproxy
    minion:
      mine_functions:
        network.ip_addrs:
          interface: eth0
      grains:
        roles: rproxy
  
ubuntu_1GB_ny2:
  - appserver-01
    minion:
      mine_functions:
        network.ip_addrs:
          interface: eth0
      grains:
        roles: appserver
          
  - appserver-02
    minion:
      mine_functions:
        network.ip_addrs:
          interface: eth0
      grains:
        roles: appserver
~~~~

Now we're getting somewhere! It looks like a lot but we've only added two things. Let's go over the two additions.

1)
~~~~
      grains:
        roles: appserver
~~~~
We've told Salt Cloud to modify the Salt Minion config for these VMs and add some custom grains. Specifically, give the reverse proxy the `rproxy` role and give the app servers the `appserver` role. This will come in handy when we need to dynamically configure the reverse proxy.

2)
~~~~
      mine_functions:
        network.ip_addrs:
          interface: eth0
~~~~
This will also be added to the Salt Minion config. It instructs the Minion to send the IP address found on `eth0` back to the Salt Master to be stored in the [Salt mine](http://docs.saltstack.com/en/latest/topics/mine/). We'll be using that in the next part.

## Automate the Reverse Proxy
We have a common task in front of us now - install the reverse proxy and configure it. For this tutorial we'll be using Nginx as the reverse proxy. 

It's time to get our hands dirty and write a few Salt states. If it doesn't exist yet, go ahead and make the default Salt state tree location:

~~~~
mkdir /srv/salt
~~~~  

Navigate into that directory and make one more directory just for nginx:
~~~~
cd /srv/salt
mkdir nginx
~~~~
Go into that directory and, using your favorite editor, create a new file called `rproxy.sls`:
~~~~
cd nginx
vim rproxy.sls
~~~~

Place the following into that file:
~~~~
### /srv/salt/nginx/rproxy.sls
### Install nginx and configure it as a reverse proxy, pulling the IPs of
### the app servers from the Salt Mine.

nginx-rproxy:
  pkg:
    - installed
    - name: nginx
  file:
    - managed
    - source: salt://nginx/files/rproxy.conf
    - name: /etc/nginx/conf.d/awesome-app.conf.jin
    - template: jinja
    - require:
      - pkg: nginx-rproxy
~~~~

That's our Salt state. But that's not too interesting. It just installs Nginx and drops a config file. The good stuff is in that config file.


## Querying Salt Mine to Configure the Reverse Proxy 
Let's make one more directory and write that config file:
~~~~
mkdir files
cd files
vim awesome-app.conf.jin
~~~~

And put the following in that config file:
~~~~
### /srv/salt/nginx/files/awesome-app.conf.jin
### Configuration file for Nginx to act as a 
### reverse proxy for an app farm.

upstream awesome-app {
    {% for server, addrs in salt['mine.get']('roles:appserver', 'network.ip_addrs', expr_form='grain').items() %}
    server {{ addrs[0] }}
    {% endfor %}
}

server {
    listen       80;
    server_name  {{ salt['network.ip_addrs']()[0] }};
 
    access_log  /var/log/nginx/log/awesome-app.access.log  main;
    error_log  /var/log/nginx/log/awesome-app.error.log;
 
    ## send request back to apache1 ##
    location / {
     proxy_pass  awesome-app;
     proxy_set_header        Host            $host;
     proxy_set_header        X-Real-IP       $remote_addr;
     proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
   }
}
~~~~
This Nginx config has two parts - 1) an upstream (our app farm) and 2) the configuration to act as a proxy between the user and our app farm. Let's look at the upstream config.

Before we explain what we did for the upstream, let's look at a normal, non-templated config.
~~~~
upstream hard-coded {
  server 10.10.10.1
  server 10.10.10.2
}
~~~~
That's it. That tells Nginx that there's an upstream that is served up by that collection of IPs. 

Protip: The default behavior in Nginx is to use a round-robin method of load balancing. You can easily specify other methods (such as `least connected` or `sticky` sessions). See [the Nginx doc](http://nginx.org/en/docs/http/load_balancing.html) for more.

Back to us. We don't know what the IP of our Minions will be until they exist. And we don't edit config files *by hand*. We're better than that. Remember our `mine_function` lines in our map file? The Minions are giving their IP to the Salt Master to store them for just such an occassion. Let's look at that Jinja line a little closer:

~~~~
{% for server, addrs in salt['mine.get']('roles:appserver', 'network.ip_addrs', expr_form='grain').items() %}
~~~~

This is a for-loop in Jinja, running an arbitrary Salt function. In this case, it's running [`mine.get`](http://docs.saltstack.com/en/latest/ref/modules/all/salt.modules.mine.html#salt.modules.mine.get). The parameters are:

* `roles:appserver` - This says to just get the details from the Minions who have the 'appserver' role.
* `network.ip_addrs` - This is the data we want to get out of the mine. We specified this in our map file as well.
* `expr_form='grain'` - This tells Salt that we're targeting our minions based on their grains. More on matching by grain at [the Saltstack doc](http://docs.saltstack.com/en/latest/topics/targeting/grains.html).

Following this loop, the variable `addr` contains a list of IP addresses (even if it's only one address). Because it's a list, we have to grab the first element with `[0]`.

That's the upstream. As for the server name:
~~~~
server_name  {{ salt['network.ip_addrs']()[0] }};
~~~~

This is the same trick as the Salt mine call (call a Salt function in Jinja). It's just simpler. It's calling [`network.ip_addrs`](http://docs.saltstack.com/en/latest/ref/modules/all/salt.modules.network.html#salt.modules.network.ip_addrs) and taking the first element of the returned list. This also lets us avoid having to manually edit our file.

## Build the App Farm
A reverse proxy doesn't mean much if it doesn't have an app behind it. Let's make a small Nodejs application that just reports the IP of the server it's on (so we can confirm we're reaching both machines).

Back in our state tree, make a new directory called `awesome-app`. Create a new file called `app.sls`.
~~~~
cd /srv/salt
mkdir awesome-app
cd awesome-app
vim app.sls
~~~~

Place the following into the file:

~~~~
### /srv/salt/awesome-app/app.sls
### Install Nodejs and start a simple
### web application that reports the server IP.

install-app:
  pkg:
    - installed
    - name: node
  file:
    - managed
    - source: salt://awesome-app/files/app.js
    - name: /root/app.js
  npm:
    - installed
    - forever
    - require:
      - pkg: install-app
    
run-app:
  cmd:
    - run
    - name: forever start app.js
    - cwd: /root
~~~~  

Now create the (small!) app code:
~~~~
mkdir file
cd files
vim app.js
~~~~

Place the following code into the file:
~~~~
/* /srv/salt/awesome-app/files/app.js
   A simple NodeJS web application that
   reports the server's IP.
   Shamefully stolen from StackOverflow:
   http://stackoverflow.com/questions/10750303/how-can-i-get-the-local-ip-address-in-node-js
*/

var os = require('os');
var http = require('http');

http.createServer(function (req, res) {
  var interfaces = os.networkInterfaces();
  var addresses = [];
  for (k in interfaces) {
      for (k2 in interfaces[k]) {
          var address = interfaces[k][k2];
          if (address.family == 'IPv4' && !address.internal) {
              addresses.push(address.address)
          }
      }
  }

  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end(JSON.stringify(addresses));
}).listen(1337, '0.0.0.0');
console.log('Server listening on port 1337');

~~~~ 

 