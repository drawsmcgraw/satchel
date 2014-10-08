# Use Salt Cloud Map Files to Deploy Application Servers and a Reverse Proxy.

### In this tutorial we'll show you how to define your application in a Salt Cloud map file, including the use of custom grains to assign roles to your servers and dynamically configure a reverse proxy. At the end of this tutorial, you will have:

* Two basic app servers
* An nginx reverse proxy with a dynamically-built configuration
* The ability to scale your application in  minutes

## Prerequisites

### A Note About Your Salt Master
The Salt Master that you use for this tutorial will need to be accessible to the minions you will create. This means that if you're on your home machine behind a NAT'd network, you'll need to create a droplet (or some other publicly-accessible machine) and use that for your Salt Master.

### Install Salt
You'll need to have Salt Cloud configured on your machine. Fortunately, since [Salt Cloud is part of salt since version Hydrogen](https://github.com/saltstack/salt-cloud), simply installing Salt gets us Salt Cloud. For the RHEL family (RedHat, CentOS, etc...), we'll just use the Salt bootstrap script. For Ubuntu, we'll need a few extra steps. For more production-like environments, you'll want to [read the documentation for your OS](http://docs.saltstack.com/en/latest/topics/installation/).

On RHEL systems.
~~~~
# Fetch and run the Salt bootstrap script to install Salt
wget -O install_salt.sh https://bootstrap.saltstack.com

# Use the -M flag to also install 'salt-master' so we get salt cloud
sh install_salt.sh -M
~~~~

On Ubuntu
~~~~
# Add the PPA
sudo add-apt-repository ppa:saltstack/salt

# Salt Cloud requires libcloud. We'll install via Pip
sudo apt-get intall python-pip
sudo pip install apache-libcloud

# Install Salt Cloud
sudo apt-get install salt-cloud salt-master
~~~~

Confirm a successful installation when done.

~~~~
root@ubuntu-salt:/var/tmp# salt-cloud --version                                                                                                                                                                      
salt-cloud 2014.1.11 (Hydrogen)
~~~~

### Configure Salt Cloud
Regardless of installation method, configuring Salt Cloud will be the same. You'll need at least one `provider` (e.g. Digital Ocean) and at least one `profile` (e.g. Ubuntu 512MB).Those are defined at the following locations (NOTE: You may need to make these directories yourself if they don't exist):

* `/etc/salt/cloud.providers.d` -- cloud providers (e.g. digitalocean)
* `/etc/salt/cloud.profiles.d` -- cloud profiles (e.g. ubuntu_2GB)

For this tutorial, let's put the following in `/etc/salt/cloud.providers.d/digital_ocean.conf`:

~~~~
do:
  provider: digital_ocean
  minion:                       #########################################
    master: 10.10.10.10  # <--- CHANGE THIS to be your Salt Master's IP #
                                #########################################
  # Digital Ocean account keys
  client_key: YourClientIDCopiedFromControlPanel
  api_key: YourAPIKeyCopiedFromControlPanel
  
  # This is the name of your SSH key in your Digital Ocean account
  # as it appears in the control panel.          #################################
  ssh_key_name: digital-ocean-salt-cloud # <---  CHANGE THIS to be your key name #
                                                 #################################
  
  # This is the path on disk to the private key for your Digital Ocean account
                                                                    ####################################
  ssh_key_file: /home/root/keys/digital-ocean-salt-cloud.key # <--- CHANGE THIS to be your private key #
                                                                    ####################################
~~~~  

And we'll put the following in `/etc/salt/cloud.profiles.d/digital_ocean.conf`:

~~~~
ubuntu_512MB_ny2:
  provider: do
  image: Ubuntu 14.04 x64
  size: 512MB
#  script: Optional Deploy Script Argument
  location: New York 2
  private_networking: True

ubuntu_1GB_ny2:
  provider: do
  image: Ubuntu 14.04 x64
  size: 1GB
#  script: Optional Deploy Script Argument
  location: New York 2
  private_networking: True

~~~~

Test your configuration with a quick query. Assuming you have some droplets on Digital Ocean, you should see something like the following.

~~~~
root@ubuntu-salt:/var/tmp# salt-cloud -Q
[INFO    ] salt-cloud starting
do:
    ----------
    digital_ocean:
        ----------
        centos-salt:
            ----------
            id:
                2806501
            image_id:
                6372108
            public_ips:
                192.241.247.229
            size_id:
                63
            state:
                active
        ubuntu-salt:
            ----------
            id:
                2806503
            image_id:
                6510539
            public_ips:
                104.131.241.28
            size_id:
                66
            state:
                active


~~~~



## Map Files - The Beginning
Going with the above profiles, let's say you want two 1GB app servers fronted by a single 512MB reverse proxy. You can place mapfiles wherever is best for you but for this demonstration, let's make a mapfile in `/etc/salt/cloud.maps.d/do-app-with-rproxy.map` and put the following in it:

~~~~
ubuntu_512MB_ny2:
  - nginx-rproxy
  
ubuntu_1GB_ny2:
  - appserver-01
  - appserver-02
~~~~

That's it! That's about as simple as a Map File gets. Go ahead and try it out with:

~~~~
salt-cloud -P -m /etc/salt/cloud.maps.d/do-app-with-rproxy.map
~~~~

The `-P` is for 'parallel`, telling Salt Cloud to launch all three VMs at the same time (as opposed to one after the other).

Confirm success with a quick ping:

~~~~
salt '*' test.ping
~~~~

Once you've successfully created the VMs in your map file, deleting them is just as easy:
~~~~
salt-cloud -d -m /etc/salt/cloud.maps.d/do-app-with-rproxy.conf
~~~~

Be sure to use that one with caution, though! It will delete *all* the VMs specified in that map file.

## Map Files - Moar Cloud
That's nice and all, but a shell script can make a set of VMs. What we need is to define the footprint of our application. Let's go back to our map file and add the following:

~~~~
ubuntu_512MB_ny2:
  - nginx-rproxy:
      minion:
        mine_functions:
          network.ip_addrs:
            interface: eth0
        grains:
          roles: rproxy
ubuntu_1GB_ny2:
- appserver-01:
    minion:
      mine_functions:
        network.ip_addrs:
            interface: eth0
      grains:
        roles: appserver
- appserver-02:
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

## Define the Reverse Proxy
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
    - source: salt://nginx/files/awesome-app.conf.jin
    - name: /etc/nginx/conf.d/awesome-app.conf
    - template: jinja
    - require:
      - pkg: nginx-rproxy
  service:
    - running
    - enable: True
    - name: nginx
    - require:
      - pkg: nginx-rproxy
    - watch:
      - file: nginx-rproxy
  cmd:
    - run
    - name: service nginx restart
    - require:
      - file: nginx-rproxy
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
    server {{ addrs[0] }}:1337;
    {% endfor %}
}

server {
    listen       80;
    server_name  {{ salt['network.ip_addrs']()[1] }};  # <-- change the '1' to '0' if you're not using 
                                                       #     Digital Ocean's private networking.

    access_log  /var/log/nginx/awesome-app.access.log;
    error_log  /var/log/nginx/awesome-app.error.log;

    ## forward request to awesome-app ##
    location / {
     proxy_pass  http://awesome-app;
     proxy_set_header        Host            $host;
     proxy_set_header        X-Real-IP       $remote_addr;
     proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
   }
}
~~~~
We use the `.jin` extension to tell ourselves that the file contains [Jinja templating](http://docs.saltstack.com/en/latest/ref/renderers/all/salt.renderers.jinja.html).

This Nginx config has two parts - 1) an upstream (our app farm) and 2) the configuration to act as a proxy between the user and our app farm. Let's look at the upstream config.

Before we explain what we did for the upstream, let's look at a normal, non-templated upstream.
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

* `roles:appserver` - This says to only get the details from the Minions who have the 'appserver' role.
* `network.ip_addrs` - This is the data we want to get out of the mine. We specified this in our map file as well.
* `expr_form='grain'` - This tells Salt that we're targeting our minions based on their grains. More on matching by grain at [the Saltstack doc](http://docs.saltstack.com/en/latest/topics/targeting/grains.html).

Following this loop, the variable `addr` contains a list of IP addresses (even if it's only one address). Because it's a list, we have to grab the first element with `[0]`.

That's the upstream. As for the server name:
~~~~
server_name  {{ salt['network.ip_addrs']()[0] }};
~~~~

This is the same trick as the Salt mine call (call a Salt function in Jinja). It's just simpler. It's calling [`network.ip_addrs`](http://docs.saltstack.com/en/latest/ref/modules/all/salt.modules.network.html#salt.modules.network.ip_addrs) and taking the first element of the returned list. This also lets us avoid having to manually edit our file.

## Define the App Farm
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
    - names: 
      - node
      - npm
      - nodejs-legacy  # workaround for Debian systems
  file: 
    - managed
    - source: salt://awesome-app/files/app.js
    - name: /root/app.js
  cmd:
    - run
    - name: npm install forever -g
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
mkdir files
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

At this point, you should have a file structure that looks like the following:

~~~~
/srv/salt
         ├── awesome-app
         │   ├── app.sls
         │   └── files
         │       └── app.js
         └── nginx
             ├── files
             │   └── awesome-app.conf.jin
             └── rproxy.sls
~~~~

## Deploy!
We're done! All that's left is to deploy the application.

~~~~
salt-cloud -P -m /etc/salt/cloud.maps.d/do-app-with-rproxy.map
~~~~

Wait for Salt Cloud to complete (it can take a few minutes). Once it returns, confirm successful deployment with a quick test:

~~~~
[root@salt-master salt]# salt -G 'roles:appserver' test.ping
appserver-02:
    True
appserver-01:
    True
[root@salt-master salt]# salt -G 'roles:rproxy' test.ping
nginx-rproxy:
    True
~~~~

If you don't see output like this, try the `test.ping` a couple more times (sometimes it can take a minute for the minions to check in). If the minions are still not reporting in (and if you saw any errors during the salt-cloud deployment), remove the VMs and re-run the deployment with:

~~~~
# Delete the VMs
salt-cloud -d -m /etc/salt/cloud.maps.d/do-app-with-rproxy.map

# Re-deploy the VMs
salt-cloud -P -m /etc/salt/cloud.maps.d/do-app-with-rproxy.map
~~~~

Once you have your VMs, it's time to give them work.

~~~~
# Deploy the app farm
salt -G 'roles:appserver' state.sls awesome-app.app

# Deploy the reverse proxy
salt -G 'roles:rproxy' state.sls nginx.rproxy
~~~~

You should see (a lot of) output ending in something like the following:

~~~~
Summary
------------
Succeeded: 6
Failed:    0
------------
Total:     6
~~~~

Once those Salt runs complete, you can test to confirm successful deployment. Find the ip of your reverse proxy:

~~~~
salt -G 'roles:rproxy' network.ip_addrs
~~~~

Plug that IP into your browser and profit! Hit refresh a few times to confirm that Nginx is actually proxying among the two app servers you built.

We can take this a few steps further and *completely* automate the application deployment via [overstate](http://docs.saltstack.com/en/latest/topics/tutorials/states_pt5.html#states-overstate) but that's an exercise for later.

## Scale it!
If you need more servers for your app farm (or more Nginx servers for load balancing), just revisit that map file, add another entry for each new server, and re-run the instructions in the "Deploy!" section. The existing VMs won't be impacted by the repeat Salt run and the new VMs will be built-to-spec and join the application.