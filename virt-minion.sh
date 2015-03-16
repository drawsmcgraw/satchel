# Sad workaround until I get salt-virt to actually bootstrap new minions.

MASTER=some-ip
yum install -y salt-minion
mkdir /etc/salt/minion.d
echo "master: $MASTER" > /etc/salt/minon.d/master.conf
chkconfig salt-minion on
service salt-minion start
