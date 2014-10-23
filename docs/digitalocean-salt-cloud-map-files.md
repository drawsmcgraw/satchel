<!--
Changelog:
- Moved Salt Cloud installation to Step One
- Added Creating a Keypair and enabling the API to prereqs
- Added an introductory paragraph
- Removed the Ubuntu section (may add back in once proven functional)
- Better organization/presentation for configuring Salt Cloud, specifically providers & profiles
-->

# Use Salt Cloud Map Files to Deploy App Servers & an Nginx Reverse Proxy


### Introduction

You have your app written and it looks great. Now you need to deploy it. You could make a production environment and set your app up on a VM. After all, it's just a clone of the code. But how do you scale it when it gets popular? How do you roll out new versions? What about load balancing? And most importantly, how can you be certain the configuration is correct? We can automate all of this to save ourselves a lot of time.

In this tutorial we'll show you how to define your application in a Salt Cloud map file, including the use of custom Salt grains to assign roles to your servers and dynamically configure a reverse proxy. At the end of this tutorial, you will have:

<!-- Please explain more why a reader skimming through this article would want to follow this tutorial; that is, what the high-level use is (saving time and having correct configurations for deployment, etc.). Also, give this introduction a quick grammar check! Thanks! -->

* Two basic app servers
* An nginx reverse proxy with a dynamically-built configuration
* The ability to scale your application in  minutes

We'll be running Salt Cloud on a CentOS VM (6.5 or 7), so you'll need to create a CentOS droplet to run through this tutorial. We'll also be creating three Ubuntu 14.04 VMs automaticaly via Salt Cloud.


## Prerequisites

### Create a Keypair and Enable the Digital Ocean API
If you don't already have an SSH key to log into Digital Ocean droplets, you'll need to create one. You can follow [How To Use SSH Keys with Digital Ocean Droplets](https://www.digitalocean.com/community/tutorials/how-to-use-ssh-keys-with-digitalocean-droplets) for instructions.

Visit the [API Access](https://cloud.digitalocean.com/api_access) page and click 'Generate New Key'. Make note of the 'Client ID' and the 'API Key'. We'll use these later when we configure Salt Cloud.

For this tutorial, we'll assume the following values:

````
Client ID: i-am-a-client-id
API Key  : this-is-my-api-key
````

### Create a CentOS VM
Since we're running salt-cloud on CentOS, you'll need to create a VM and log into it. A 1GB / 1cpu VM should be plenty. 

All commands in this tutorial will be run as root.

### Salt Master Must Be Accesible to Minions
The Salt Master that you use for this tutorial will need to be accessible to the minions you will create. This means that if you're on your home machine behind a NAT'd network, you'll need to create a droplet (or some other publicly-accessible machine) and use that for your Salt Master.

<!--

Some notes about section headers:

This one doesn't need it, but when you get to the main steps, we typically use "Step One — Action" as the section header.

With this title and others, see how descriptive you can be. For example, "Salt Master Must Be Accessibl to Minions" describes the section at a glance.

If someone just skimmed through the tutorial reading only the headers, they should have a perfect sense of the summary of each section.
 
-->

## Step One - Install Salt and Salt Cloud

You'll need to have Salt Cloud configured on your machine. Fortunately, since [Salt Cloud is part of salt since version Hydrogen](https://github.com/saltstack/salt-cloud), simply installing Salt gets us Salt Cloud. For this tutorial, we'll just use the Salt bootstrap script. For more production-like environments, you'll want to [read the documentation for your OS](http://docs.saltstack.com/en/latest/topics/installation/).

<!-- I would change the focus of this paragraph slightly to say that the reader should start by installing Salt and Salt Cloud. The fact that the installation method changed can be more of a side note in the paragraph. -->



Fetch the Salt bootstrap script to install Salt.

````
wget -O install_salt.sh https://bootstrap.saltstack.com
````

Run the Salt bootstrap script. We use the -M flag to also install 'salt-master' so we get salt cloud.

````
sh install_salt.sh -M
````


Check Salt Cloud's version to confirm a successful installation:

````
salt-cloud -version
````

You should see output like this:

````
salt-cloud 2014.1.11 (Hydrogen)
````


## Step Two - Configure Salt Cloud

<!-- I'm not sure this should be a Level 3 header; it seems like a significant enough step to be a Level 2 header. I would write out all of the headers you have in this tutorial and make sure they are all descriptive and at the right level. Does the TOC by itself make a good structure for this tutorial?

-->

<!--

Actual steps in this section. Please put these on their own lines with appropriate explanations. You can link to the SSH Keys tutorial if you want to.

These actions are to be completed on the Salt Master host as the **root** user.

[root@saltmap2 ~]# mkdir /etc/salt/cloud.providers.d
[root@saltmap2 ~]# mkdir /etc/salt/cloud.profiles.d

ssh-keygen -t rsa

Add this key to the DigitalOcean control panel.

While you're in the control panel, you have to enable the API, go to the first version of the API, and generate and note down an ID and a key. You should either provide screenshots for this or link to a tutorial that has a thorough explanation of how to use the first version of the API.

Side note - does Salt Cloud have a way to use the newer version of the API?

nano /etc/salt/cloud.providers.d/digital_ocean.conf

-->

Regardless of installation method, configuring Salt Cloud will be the same. You'll need at least one `provider` (e.g. Digital Ocean) and at least one `profile` (e.g. Ubuntu 512MB).Those are defined at the following locations (NOTE: You may need to make these directories yourself if they don't exist):

* `/etc/salt/cloud.providers.d` -- cloud providers (e.g. digitalocean)
* `/etc/salt/cloud.profiles.d` -- cloud profiles (e.g. ubuntu_2GB)

### Configure The Digital Ocean Provider
In Salt Cloud, 'providers' are how you define where the new VMs will be created). 

Configure the Digital Ocean provider: 

````
nano /etc/salt/cloud.providers.d/digital_ocean.conf
````

Insert the below text. 

````
### /etc/salt/cloud.providers.d/digital_ocean.conf ###
######################################################
do:
  provider: digital_ocean
  minion:                      
    master: <^>10.10.10.10<^>  
                                
  # Digital Ocean account keys
  client_key: <^>i-am-a-client-id<^>
  api_key: <^>this-is-my-api-key<^>
  
  # This is the name of your SSH key in your Digital Ocean account
  # as it appears in the control panel.          
  ssh_key_name: <^>digital-ocean-salt-cloud<^> 
  
  # This is the path on disk to the private key for your Digital Ocean account
                                                                    
  ssh_key_file: <^>/root/.ssh/digital-ocean-salt-cloud.key<^>                                                                
````

There are several values here that you'll need to change.

**master** - This is the IP of the Salt master that you are using.

**client_key** - This is your Digital Ocean Client ID from the API Access page. 

**api_key** - This is your Digital Ocean API key, also from the Digital Ocean API Access page. 

**ssh_key_name** - This is the name of the SSH key you use to log into droplets as it appears on the [SSH Keys](https://cloud.digitalocean.com/ssh_keys) page on the Digital Ocean console.

**ssh_key_file** - This is the path, on disk, where Salt Cloud can find the private key that it will use to log into new droplets.


<!-- 

You already created an updated version of this config file that you can put here instead of this one.

Make sure that you thoroughly explain where each of these values is coming from (the IP, the API stuff, and the SSH key stuff). You'll probably want this in paragraphs either above or below the file, in addition to having short in-line comments.

Also, can you make sure any comments you add in the file have good ASCII formatting so it doesn't end up looking off when it gets copied and pasted?

Finally, you can use a special syntax like this:

<^>mark variables<^>

This symbol (<^>) will make everything between it highlighted in red.

-->

### Configure The Digital Ocean Profiles
In Salt Cloud, 'profiles' are individual VM descriptions that are tied to a provider. An example of a profile can be "A 512MB Ubuntu VM in Digital Ocean".


Configure the profiles:

````
nano /etc/salt/cloud.profiles.d/digital_ocean.conf
````

Paste the following into the file. No modification is necessary:

````
### /etc/salt/cloud.profiles.d/digital_ocean.conf ###
#####################################################

ubuntu_512MB_ny2:
  provider: do
  image: Ubuntu 14.04 x64
  size: 512MB
#  script: Optional Deploy Script Argument
  location: New York 3
  private_networking: True

ubuntu_1GB_ny2:
  provider: do
  image: Ubuntu 14.04 x64
  size: 1GB
#  script: Optional Deploy Script Argument
  location: New York 3
  private_networking: True

````

This file defines two profiles:

* An Ubuntu 14.04 VM with 512MB of memory, living in the New York 3 data canter.
* An Ubunto 14.04 VM with 1GB of memory, living in the New York 3 data center.

No additional configuration is needed in this file.

We found the image name by using Salt Cloud to get a listing of images in Digital Ocean. For example, to get a listing of available images in Digital Ocean using our configuration, we would type:

````
salt-cloud --list-images do
````

The output is long, but the part where our image is looks like this:

````
         Ubuntu 14.04 x64:
            ----------
            distribution:
                Ubuntu
            id:
                6918990
            name:
                Ubuntu 14.04 x64
            public:
                True
            region_slugs:
                [u'nyc1', u'ams1', u'sfo1', u'nyc2', u'ams2', u'sgp1', u'lon1', u'nyc3', u'ams3']
            regions:
                [1, 2, 3, 4, 5, 6, 7, 8, 9]
            slug:
                ubuntu-14-04-x64
    

````


<!-- 

Can you introduce a bit more what this file does? It can be a sentence or two.

Maybe this should switch to NY 3, because that's the newer data center?

You can let the reader know that they can copy this file exactly 

-->

Moving on. Test your configuration with a quick query.

````
salt-cloud -Q
````

Assuming you have some droplets on Digital Ocean, you should see something like the following.

````
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


````

<!-- Please separate commands and output, here and throughout the tutorial. Thanks! Also, we don't need the shell prompt.

-->


## Step Three - Write a Simple Map File

<!-- 

"Simple Deployment" or something similar is more descriptive than "The Beginning"

-->

Going with the above profiles, let's say you want two 1GB app servers fronted by a single 512MB reverse proxy. You can place mapfiles wherever is best for you but for this demonstration, let's make a mapfile in `/etc/salt/cloud.maps.d/do-app-with-rproxy.map` and define the app.

Create the directory:

````
mkdir /etc/salt/cloud.maps.d/
````

Create the file:

````
nano /etc/salt/cloud.maps.d/do-app-with-rproxy.map
````

Insert the following text. No modification is necessary:

````
### /etc/salt/cloud.maps.d/do-app-with-rproxy.map ####
######################################################
ubuntu_512MB_ny2:
  - nginx-rproxy
  
ubuntu_1GB_ny2:
  - appserver-01
  - appserver-02
````
<!--

mkdir /etc/salt/cloud.maps.d/

nano /etc/salt/cloud.maps.d/do-app-with-rproxy.map

I suggest putting the appropriate nano or vim command on its own line before every single example file. That way the reader will easily be able to start editing the correct file, and it will save headaches like the ones we ran into during testing!

-->

That's it! That's about as simple as a Map File gets. Go ahead and try it out with:

````
salt-cloud -P -m /etc/salt/cloud.maps.d/do-app-with-rproxy.map
````

The `-P` is for 'parallel`, telling Salt Cloud to launch all three VMs at the same time (as opposed to one after the other).

You should see output similar to the following:

````
[INFO    ] salt-cloud starting
[INFO    ] Applying map from '/etc/salt/cloud.maps.d/do-app-with-rproxy.map'.
The following virtual machines are set to be created:
  appserver-01
  appserver-02
  nginx-rproxy

Proceed? [N/y] y
... proceeding
.
.
.
[INFO    ] Salt installed on appserver-01
[INFO    ] Created Cloud VM 'appserver-01'
[INFO    ] Salt installed on appserver-02
[INFO    ] Created Cloud VM 'appserver-02'
[INFO    ] Salt installed on nginx-rproxy
[INFO    ] Created Cloud VM 'nginx-rproxy'
appserver-01:
    ----------
    backups_active:
        False
    created_at:
        2014-10-14T21:19:51Z
    droplet:
        ----------
        event_id:
            34406200
        id:
            2874010
        image_id:
            6713522
        name:
            appserver-01
        size_id:
            63
    id:
        2874010
    image_id:
        6713522
    ip_address:
        107.170.79.180
    locked:
        True
    name:
        appserver-01
    private_ip_address:
        10.128.128.193
    region_id:
        4
    size_id:
        63
    status:
        new
.
.
.
<output clipped for brevity>
````

<!-- You don't have to show all of it, but it might be good to show the last few lines of successful output

[root@saltmap2 ~]# salt-cloud -P -m /etc/salt/cloud.maps.d/do-app-with-rproxy.map
[INFO    ] salt-cloud starting
[INFO    ] Applying map from '/etc/salt/cloud.maps.d/do-app-with-rproxy.map'.
The following virtual machines are set to be created:
  appserver-01
  appserver-02
  nginx-rproxy

Proceed? [N/y] y
... proceeding
[INFO    ] Calculating dependencies for appserver-01
[INFO    ] Calculating dependencies for appserver-02
[INFO    ] Calculating dependencies for nginx-rproxy
[INFO    ] Since parallel deployment is in use, ssh console output is disabled. All ssh output will be logged though
[INFO    ] Cloud pool size: 3
[INFO    ] Creating Cloud VM appserver-01
[INFO    ] Creating Cloud VM nginx-rproxy
[INFO    ] Creating Cloud VM appserver-02
[INFO    ] Rendering deploy script: /usr/lib/python2.7/site-packages/salt/cloud/deploy/bootstrap-salt.sh
[INFO    ] Rendering deploy script: /usr/lib/python2.7/site-packages/salt/cloud/deploy/bootstrap-salt.sh
[INFO    ] Rendering deploy script: /usr/lib/python2.7/site-packages/salt/cloud/deploy/bootstrap-salt.sh
[INFO    ] Salt installed on appserver-01
[INFO    ] Created Cloud VM 'appserver-01'
[INFO    ] Salt installed on appserver-02
[INFO    ] Created Cloud VM 'appserver-02'
[INFO    ] Salt installed on nginx-rproxy
[INFO    ] Created Cloud VM 'nginx-rproxy'
appserver-01:
    ----------
    backups_active:
        False
    created_at:
        2014-10-14T21:19:51Z
    droplet:
        ----------
        event_id:
            34406200
        id:
            2874010
        image_id:
            6713522
        name:
            appserver-01
        size_id:
            63
    id:
        2874010
    image_id:
        6713522
    ip_address:
        107.170.79.180
    locked:
        True
    name:
        appserver-01
    private_ip_address:
        10.128.128.193
    region_id:
        4
    size_id:
        63
    status:
        new
appserver-02:
    ----------
    backups_active:
        False
    created_at:
        2014-10-14T21:19:53Z
    droplet:
        ----------
        event_id:
            34406202
        id:
            2874011
        image_id:
            6713522
        name:
            appserver-02
        size_id:
            63
    id:
        2874011
    image_id:
        6713522
    ip_address:
        107.170.22.18
    locked:
        True
    name:
        appserver-02
    private_ip_address:
        10.128.129.4
    region_id:
        4
    size_id:
        63
    status:
        new
nginx-rproxy:
    ----------
    backups_active:
        False
    created_at:
        2014-10-14T21:19:55Z
    droplet:
        ----------
        event_id:
            34406203
        id:
            2874012
        image_id:
            6713522
        name:
            nginx-rproxy
        size_id:
            66
    id:
        2874012
    image_id:
        6713522
    ip_address:
        104.131.216.16
    locked:
        True
    name:
        nginx-rproxy
    private_ip_address:
        10.128.129.44
    region_id:
        4
    size_id:
        66
    status:
        new

-->

Confirm success with a quick ping:

````
salt '*' test.ping
````

You should see the following:

````
appserver-01:
    True
appserver-02:
    True
nginx-rproxy:
    True
````

If nothing comes back, try the `test.ping` command again a few times. Sometimes it can take a moment before the minions check in to the master.

<!-- Successful output should look like? -->

Once you've successfully created the VMs in your map file, deleting them is just as easy:

````
salt-cloud -d -m /etc/salt/cloud.maps.d/do-app-with-rproxy.map
````

<!--

Wrong file path in original, use

/etc/salt/cloud.maps.d/do-app-with-rproxy.map

-->

Be sure to use that one with caution, though! It will delete *all* the VMs specified in that map file.

## Step Four - Update the Map File

<!-- Please update this header to be more descriptive. Thanks! -->

That's nice and all, but a shell script can make a set of VMs. What we need is to define the footprint of our application. Let's go back to our map file and add a few more things.

````
nano /etc/salt/cloud.maps.d/do-app-with-rproxy.map
````

<!-- Give file name again 

vim /etc/salt/cloud.maps.d/do-app-with-rproxy.map

-->

Delete the previous contents of the file and place the following into it. No modification is needed:

````
### /etc/salt/cloud.maps.d/do-app-with-rproxy.map ###
#####################################################
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

````

Now we're getting somewhere! It looks like a lot but we've only added two things. Let's go over the two additions.

1)
````
      grains:
        roles: appserver
````

We've told Salt Cloud to modify the Salt Minion config for these VMs and add some custom [grains](http://docs.saltstack.com/en/latest/topics/targeting/grains.html). Specifically, give the reverse proxy VM the `rproxy` role and give the app servers the `appserver` role. This will come in handy when we need to dynamically configure the reverse proxy.

<!-- What are grains? Please provide a link and/or brief explanation -->

2)
````
      mine_functions:
        network.ip_addrs:
          interface: eth0
````

This will also be added to the Salt Minion config. It instructs the Minion to send the IP address found on `eth0` back to the Salt Master to be stored in the [Salt mine](http://docs.saltstack.com/en/latest/topics/mine/). This means the Salt Master will automatically know the IP of the newly-created droplet without us having to configure it. We'll be using this in the next part.

<!-- Can you explain more what this accomplishes? For someone new to Salt, what does this mean? -->

## Step Five - Define the Reverse Proxy

We have a common task in front of us now - install the reverse proxy and configure it. For this tutorial we'll be using Nginx as the reverse proxy. 

### Write the Nginx Salt State

It's time to get our hands dirty and write a few Salt states. If it doesn't exist yet, go ahead and make the default Salt state tree location:

````
mkdir /srv/salt
````  

Navigate into that directory and make one more directory just for nginx:

````
cd /srv/salt
mkdir /srv/salt/nginx
````



Go into that directory and, using your favorite editor, create a new file called `rproxy.sls`:

````
cd /srv/salt/nginx
nano /srv/salt/nginx/rproxy.sls
````

<!-- Please use complete file names throughout the tutorial. -->

Place the following into that file. No modification is needed:

````
### /srv/salt/nginx/rproxy.sls ###
##################################

### Install nginx and configure it as a reverse proxy, pulling the IPs of
### the app servers from the Salt Mine.

nginx-rproxy:
  # Install Nginx
  pkg:
    - installed
    - name: nginx    
  # Place a customized Nginx config file
  file:
    - managed
    - source: salt://nginx/files/awesome-app.conf.jin
    - name: /etc/nginx/conf.d/awesome-app.conf
    - template: jinja
    - require:
      - pkg: nginx-rproxy
  # Ensure Nginx is always running.
  # Restart Nginx if the config file changes.
  service:
    - running
    - enable: True
    - name: nginx
    - require:
      - pkg: nginx-rproxy
    - watch:
      - file: nginx-rproxy
  # Restart Nginx for the initial installation.
  cmd:
    - run
    - name: service nginx restart
    - require:
      - file: nginx-rproxy
````

<!-- Please explain what this does more thoroughly. Users should be able to follow along with the main blocks and settings in every config file in the tutorial. That way, they will be able to customize their own setups and/or troubleshoot when something goes wrong.

You can provide explanation in paragraphs or bullet points above or below the sample file, or you can link to a different tutorial that explains similar files. -->

This state does the following:

* Installs Nginx
* Places our custom config file into `/etc/nginx/conf.d/awesome-app.conf`
* Ensures Nginx is running

That's our Salt state. But that's not too interesting. It just installs Nginx and drops a config file. The good stuff is in that config file.


### Write the Nginx Reverse Proxy Config

Let's make one more directory for our config file:and write that config file:

````
mkdir /srv/salt/nginx/files
cd /srv/salt/nginx/files
````

And write the config file:

````
nano /srv/salt/nginx/files/awesome-app.conf.jin
````

<!-- You can combing mdkir and cd, but please put the vim command on its own line. -->

Put the following in the config file. No modification is necessary:

````
### /srv/salt/nginx/files/awesome-app.conf.jin ###
##################################################

### Configuration file for Nginx to act as a 
### reverse proxy for an app farm.

# Define the app servers that we're in front of.
upstream awesome-app {
    {% for server, addrs in salt['mine.get']('roles:appserver', 'network.ip_addrs', expr_form='grain').items() %}
    server {{ addrs[0] }}:1337;
    {% endfor %}
}

# Forward all port 80 http traffic to our app farm, defined above as 'awesome-app'.
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
````

We use the `.jin` extension to tell ourselves that the file contains [Jinja templating](http://docs.saltstack.com/en/latest/ref/renderers/all/salt.renderers.jinja.html). Jinja templating allows us to put a small amount of logic into our text files so we can dynamically generate config details.

<!-- Please add another sentence or two about Jinja for the beginning Salt or Jinja user. -->

This config file instructs Nginx to take all port 80 http traffic and forward it on to our app farm.

This Nginx config has two parts - 1) an upstream (our app farm) and 2) the configuration to act as a proxy between the user and our app farm. Let's look at the upstream config.

<!-- Thanks for providing some additional explanation here. I think it could go one step further in explaining what this file accomplishes, though. -->

Before we explain what we did for the upstream, let's look at a normal, non-templated upstream.

````
upstream hard-coded {
  server 10.10.10.1
  server 10.10.10.2
}
````

That's it. That tells Nginx that there's an upstream that is served up by that collection of IPs. To learn more about Nginx as a reverse proxy, see [the Nginx Reverse Proxy](http://nginx.com/resources/admin-guide/reverse-proxy/) section of the Nginx admin guide.

<!-- Link to a more basic tutorial that explains this type of Nginx setup so the reader can learn more if they want to. -->

Protip: The default behavior in Nginx is to use a round-robin method of load balancing. You can easily specify other methods (such as `least connected` or `sticky` sessions). For example, to use the 'least connected' method, you would place the line in the 'upstream' section of the config like this:

````
upstream awesome-app {
  least_conn;
  .
  .
  .
}
```` 

See [the Nginx doc on load balancing](http://nginx.org/en/docs/http/load_balancing.html) for more.

<!-- Where in the file would the reader set an alternate method of balancing? -->

Back to us. We don't know what the IP of our Minions will be until they exist. And we don't edit config files *by hand*. We're better than that. Remember our `mine_function` lines in our map file? The Minions are giving their IP to the Salt Master to store them for just such an occassion. Let's look at that Jinja line a little closer:

````
{% for server, addrs in salt['mine.get']('roles:appserver', 'network.ip_addrs', expr_form='grain').items() %}
````

This is a for-loop in Jinja, running an arbitrary Salt function. In this case, it's running [`mine.get`](http://docs.saltstack.com/en/latest/ref/modules/all/salt.modules.mine.html#salt.modules.mine.get). The parameters are:

* `roles:appserver` - This says to only get the details from the Minions who have the 'appserver' role.
* `network.ip_addrs` - This is the data we want to get out of the mine. We specified this in our map file as well.
* `expr_form='grain'` - This tells Salt that we're targeting our minions based on their grains. More on matching by grain at [the Saltstack targeting doc](http://docs.saltstack.com/en/latest/topics/targeting/grains.html).

Following this loop, the variable `{{addrs}}` contains a list of IP addresses (even if it's only one address). Because it's a list, we have to grab the first element with `[0]`.

That's the upstream. As for the server name:

````
server_name  {{ salt['network.ip_addrs']()[0] }};
````

This is the same trick as the Salt mine call (call a Salt function in Jinja). It's just simpler. It's calling [`network.ip_addrs`](http://docs.saltstack.com/en/latest/ref/modules/all/salt.modules.network.html#salt.modules.network.ip_addrs) and taking the first element of the returned list. This also lets us avoid having to manually edit our file.

<!-- There are some good explanations in here! Just make sure they're all accessible to a beginner reader. -->

## Step Six - Define the App Farm
A reverse proxy doesn't mean much if it doesn't have an app behind it. Let's make a small Nodejs application that just reports the IP of the server it's on (so we can confirm we're reaching both machines).

Make a new directory called `awesome-app`. Create a new file called `app.sls`.

<!-- What is a state tree? -->

````
mkdir -p /srv/salt/awesome-app
cd /srv/salt/awesome-app
````

Create the app state file:

````
nano /srv/salt/awesome-app/app.sls
````

<!-- Please separate these commands. You could probably use a mkdir -p here. -->

Place the following into the file. No modification is necessary:

````
### /srv/salt/awesome-app/app.sls ###
#####################################

### Install Nodejs and start a simple
### web application that reports the server IP.

install-app:
  # Install prerequisites
  pkg:
    - installed
    - names: 
      - node
      - npm
      - nodejs-legacy  # workaround for Debian systems
  # Place our Node code
  file: 
    - managed
    - source: salt://awesome-app/files/app.js
    - name: /root/app.js
  # Install the package called 'forever'
  cmd:
    - run
    - name: npm install forever -g
    - require:
      - pkg: install-app
   
run-app:
  # Use 'forever' to start the server
  cmd:
    - run
    - name: forever start app.js
    - cwd: /root
````

This state file does the following:

* Installs nodejs, npm, and nodejs-legacy
* Places the Javascript file that will be our simple app
* Uses NPM to install [`Forever`](https://www.npmjs.org/package/forever)
* Runs the app

<!-- What does the file above do? --> 

Now create the (small!) app code:

````
mkdir /srv/salt/awesome-app/files
cd /srv/salt/awesome-app/files
````

Create the file:
````
vim /srv/salt/awesome-app/files/app.js
````

Place the following into it. No modification is needed:

<!-- Please separate these commands -->


````
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

```` 

This is a simple Nodejs server that only does one thing - accepts http requests on port 1337 and responds with the server's IPs. To learn more about Nodejs, see [Nodejs.org](http://nodejs.org/), which has an example of an even simpler webserver.

<!-- Please explain more thoroughly what this file does, or link to an appropriate article. For example, you can say "To learn more about Node.js apps, please read this article" with a link -->

At this point, you should have a file structure that looks like the following:

````
/srv/salt
         ├── awesome-app
         │   ├── app.sls
         │   └── files
         │       └── app.js
         └── nginx
             ├── rproxy.sls
             └── files
                 └── awesome-app.conf.jin
             
````

<!-- Chart is not uniform in how it shows subfolders and files -->

## Step Seven - Deploy!

We're done! All that's left is to deploy the application.

### Deploy the Servers With Salt Cloud

````
salt-cloud -P -m /etc/salt/cloud.maps.d/do-app-with-rproxy.map
````

Wait for Salt Cloud to complete (it can take a few minutes). Once it returns, confirm successful deployment with a quick test:

<!-- I would show a few lines of successful output -->

Ping the app servers:

````
salt -G 'roles:appserver' test.ping
````

You should see:

````
appserver-02:
    True
appserver-01:
    True
````
    
Ping the reverse proxy:

````
salt -G 'roles:rproxy' test.ping
````

You should see:

````
nginx-rproxy:
    True
````

<!-- Please separate these commands. Thanks! -->

<!--

Show successful ping output

[root@saltmap2 ~]# salt -G 'roles:appserver' test.ping
appserver-01:
    True
appserver-02:
    True
[root@saltmap2 ~]# salt -G 'roles:rproxy' test.ping
nginx-rproxy:
    True
    
--> 

If you don't see output like this, try the `test.ping` a couple more times (sometimes it can take a minute for the minions to check in). If the minions are still not reporting in (and if you saw any errors during the salt-cloud deployment), remove the VMs and re-run the deployment with:

````
# Delete the VMs
salt-cloud -d -m /etc/salt/cloud.maps.d/do-app-with-rproxy.map

# Re-deploy the VMs
salt-cloud -P -m /etc/salt/cloud.maps.d/do-app-with-rproxy.map
````

Once you have your VMs, it's time to give them work.

<!-- I would start a new section header here -->      

### Build the Application

Issue the Salt commands to automatically build the app farm and the reverse proxy.

Build the app farm:

````
salt -G 'roles:appserver' state.sls awesome-app.app
````

There will be a fair amount of output, but it should end with the following:

````
Summary
------------
Succeeded: 6
Failed:    0
------------
Total:     6
````

Build the reverse proxy:

````
salt -G 'roles:rproxy' state.sls nginx.rproxy
````

Again, there will be a fair amount of output, ending with the following:

````
Summary
------------
Succeeded: 4
Failed:    0
------------
Total:     4
````

<!-- Is the below output for both commands? I got it for deploying the 'appserver' ones. I would separate these two commands and show command 1, output 1, then command 2, output 2 -->

<!--

output for the second one

Summary
------------
Succeeded: 4
Failed:    0
------------
Total:     4

-->

So what just happened here? 

The first command (the one with the app servers) took the Salt state that we wrote earlier and executed it on the two app servers. This resulted in two machines with identical configurations running identical versions of code.

The second command (the reverse proxy) executed the Salt state we wrote for Nginx. It installed Nginx and  the configuration file, dynamically filling in the IPs of our app farm in the config file.

<!-- This would be a great place to recap what has been accomplished from a high-level technical perspective; what got deployed and why. -->

Once those Salt runs complete, you can test to confirm successful deployment. Find the ip of your reverse proxy:

````
salt -G 'rolses:rproxy' network.ip_addrs
````

You may get back two IPs if you're using private networking on your droplet.

<!-- I actually got two IPs from doing this, I think because I had private networking enabled. -->

Plug that IP into your browser and go! Hit refresh a few times to confirm that Nginx is actually proxying among the two app servers you built. You should see the IPs changing, confirming that you are, indeed, connecting to more than one app server.

<!--

I'm seeing two IPs. The first one is getting "This webpage is not available" even though the deployment seems to be successful.

The second one shows two IPs.

["107.170.79.180","10.128.128.193"]

Can you explain what should change when the page refreshes?

-->

We can take this a few steps further and *completely* automate the application deployment via [overstate](http://docs.saltstack.com/en/latest/topics/tutorials/states_pt5.html#states-overstate). This would let us build a single command to tell Salt to build, say, the app servers first before moving on to build the reverse proxy, guaranteeing the order of our build process.

<!-- You don't have to introduce overstate, but if you do, you should briefly explain how it makes deployment more automatic. -->

<!--

Can you go into a very brief "next steps" type discussion about how the reader would deploy something more practical with this kind of setup? Seeing a page with 2 IPs at the end is not immediately useful. You could say something like "You'll want to replace our awesomeapp with your own app and adjust files X and Y" or something like that.

-->

## Step Seven - Scale It!
The point of using Salt is to automate your build process. The point of using Salt Cloud and map files is to easily scale your deployment. If you wanted to add more app servers (say, two more) to your deployment, you would update your map file to look like this:

````
### /etc/salt/cloud.maps.d/do-app-with-rproxy.map ###
#####################################################
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
- appserver-03:
    minion:
      mine_functions:
        network.ip_addrs:
            interface: eth0
      grains:
        roles: appserver
- appserver-04:
    minion:
      mine_functions:
        network.ip_addrs:
            interface: eth0
      grains:
        roles: appserver        
````

After making that update, you would re-run the `salt-cloud` command and the two `salt` commands in section Six:

````
salt-cloud -P -m /etc/salt/cloud.maps.d/do-app-with-rproxy.map
salt -G 'roles:appserver' state.sls awesome-app.app
salt -G 'roles:rproxy' state.sls nginx.rproxy
````

The existing VMs wouldn't be impacted by the repeat Salt run, the new VMs would be built-to-spec, and the Nginx config would update to begin routing traffic to the new app servers.

<!-- I would give an example map file with a bigger deployment, and specify actual step numbers, like "then re-run Steps 6-7" -->

## Section Eight - Future Work
Deploying an app that just reports the server's IP isn't very useful. Fortunately, this approach is not limited to Nodejs applications. Salt doesn't care what language your app is written in.

If you wanted to take this framework to deploy your own app, you would just need to automate the task of installing your app on a server (either via a script or Salt states) and replace our `awesome-app` example with your own automation.

<!-- Thanks for all your hard work on this! -->
