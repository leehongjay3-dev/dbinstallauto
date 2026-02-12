parted /dev/sdb --script mklabel gpt
parted /dev/sdb --script mkpart primary 0% 100%
mkfs.ext4 /dev/sdb1 -F
mkdir /app
mount /dev/sdb1 /app
mkdir -p /media/os
mount -o loop  /dev/cdrom /media/os
cd /etc/yum.repos.d/
tar -cvf `hostname`.bk.tar .
mv `hostname`.bk.tar ../
mv * ../
cd
echo "[redapp8.6]             
name=redapp8.6
baseurl=file:///media/os/AppStream
enabled=1            
gpgcheck=0

[redbase8.6]             
name=redbase8.6
baseurl=file:///media/os/BaseOS
enabled=1            
gpgcheck=0" > /etc/yum.repos.d/cdbase.repo 
cat  /etc/yum.repos.d/cdbase.repo 
