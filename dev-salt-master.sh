# Install some pre-reqs
yum install -y unzip wget git GitPython vim
git config --global user.name  "drawsmcgraw"

# Fetch, then run, the Salt-bootstrap script
# -M to install salt-master
# -L to also install apache-libcloud (for salt-cloud)
# -P to allow pip-based installs (for apache-libcloud)
# -X to *not* start the daemons
wget https://raw.githubusercontent.com/saltstack/salt-bootstrap/stable/bootstrap-salt.sh
sh bootstrap-salt.sh -M -L -X -P

# Install salt-vim files
git clone https://github.com/saltstack/salt-vim.git
if [ ! -d ~/.vim ]; then
mkdir ~/.vim
fi
cp -r salt-vim/* ~/.vim/.

# Minion should connect to localhost
echo '127.0.0.1 salt' >> /etc/hosts

service salt-master start
service salt-minion start

echo "Done. Be sure to set git user.email and fix file_roots."
