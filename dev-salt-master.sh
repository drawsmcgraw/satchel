# Install some pre-reqs
yum install -y unzip wget git GitPython vim
git config --global user.name  "drawsmcgraw"
git config --global user.email "drawsmcgraw"

# Fetch, then run, the Salt-bootstrap script
# -M to install salt-master
# -L to also install apache-libcloud (for salt-cloud)
wget https://raw.githubusercontent.com/saltstack/salt-bootstrap/stable/bootstrap-salt.sh
sh bootstrap-salt.sh -M -L

# Install salt-vim files
git clone https://github.com/saltstack/salt-vim.git
if [ ! -d ~/.vim ]; then
mkdir ~/.vim
fi
cp -r salt-vim/* ~/.vim/.
