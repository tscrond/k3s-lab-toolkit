#/bin/bash -xe

systemctl stop pvestatd.service
systemctl stop pvedaemon.service
systemctl stop pve-cluster.service
systemctl stop corosync
systemctl stop pve-cluster

sqlite3 /var/lib/pve-cluster/config.db "delete from tree where name = 'corosync.conf';"

pmxcfs -l
rm /etc/pve/corosync.conf
rm /etc/corosync/*
rm /var/lib/corosync/*
rm -rf /etc/pve/nodes/*

systemctl start pve-cluster
systemctl start corosync
systemctl start pve-cluster.service
systemctl start pvedaemon.service
systemctl start pvestatd.service
