#!/bin/bash
#* wait until efs mount is finished
sleep 2m
#* update the instnce
sudo yum update -y
sudo yum install git -y 
#* install the efs client 
sudo yum install -y amazon-efs-utils
#* make the target mount
sudo mkdir /efs
#* mount the efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_ip}:/ /efs
#* insure if the instance got rebooted, the instance will remount  efs 
echo '${efs_id} ${efs_mount_id} /efs _netdev,tls,accesspoint=${efs_access_point_id} 0 0' >> /etc/fstab
sudo yum install -y docker
sudo usermod -a -G docker ec2-user
sudo service docker start
sudo chkconfig docker on
sudo docker run --name some-wordpress -p 80:80 -e WORDPRESS_DB_HOST=demodb.cdzss2jfrhfx.eu-central-1.rds.amazonaws.com:3306 -e WORDPRESS_DB_USER=user -v /efs:/var/www/html -e WORDPRESS_DB_PASSWORD=MyExamplePass\!23 -e WORDPRESS_DB_NAME=demodb -d wordpress
