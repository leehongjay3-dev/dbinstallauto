echo "
oracle          soft    nproc           2047
oracle          hard    nproc           16384
oracle          soft    nofile          1024
oracle          hard    nofile          65536
oracle          soft    stack           10240
oracle          hard    stack           32768
oracle          soft    memlock         unlimited
oracle          hard    memlock         unlimited
grid            soft    nproc           2047
grid            hard    nproc           16384
grid            soft    nofile          1024
grid            hard    nofile          65536
grid            soft    stack           10240
grid            hard    stack           32768
grid            soft    memlock         unlimited
grid            hard    memlock         unlimited 
" >> /etc/security/limits.conf


echo "
kernel.shmmax=6442450944 
net.ipv4.ip_local_port_range = 9000  65500
fs.aio-max-nr = 1048576
fs.file-max = 6815744
" >> /etc/sysctl.conf

sysctl -p

#for only db not cluster
chown oracle:oinstall /app/oraInventory/
