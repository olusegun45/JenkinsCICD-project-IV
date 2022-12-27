# Resource-7: Creat Security Group for Web Server
resource "aws_security_group" "Project-IV-SG" {
  name        = "Project-IV-SG"
  description = "Allow All traffic"
  vpc_id      = aws_vpc.Project-IV-VPC.id

  ingress    {
      description      = "All traffic"
      from_port         = 0
      to_port           = 65535
      protocol          = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

  egress     {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }

  tags = {
    Name = "Project-IV-SG"
  }
}

# Resource-8: Creat Amazon Linux 2 VM instance and call it "jenkins-maven-ansible"
resource "aws_instance" "jenkins-maven-ansible" {
  ami           = "ami-0a606d8395a538502"
  instance_type = "t2.medium"
  key_name      = "XXXXXXXXXXXX"
  subnet_id     = aws_subnet.Project-IV-VPC-Pub-sbn.id
  vpc_security_group_ids = [aws_security_group.Project-IV-SG.id]
  user_data = <<-EOF
      #!/bin/bash
      sudo yum update –y
      sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
      sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
      sudo yum upgrade
      sudo amazon-linux-extras install java-openjdk11 -y
      sudo yum install jenkins -y
      sudo systemctl enable jenkins
      sudo systemctl start jenkins

      # Installing Git
      sudo yum install git -y
      ###

      # Use The Amazon Linux 2 AMI When Launching The Jenkins VM/EC2 Instance
      # Instance Type: t2.medium or small minimum
      # Open Port (Security Group): 8080 
    EOF
  
  tags = {
    Name = "jenkins-maven-ansible"
  }
}

# Indexing
 #    0               1               2
# [instancetype-1, intancetype-2, instancetype-3]

# Resource-9: Creat Ubuntu 18.04 VM instance and call it "SonarQube"
resource "aws_instance" "SonarQube" {
  ami           = "ami-04fa64c4b38e36384"
  instance_type = "t2.medium"
  key_name      = "XXXXXXXXXXXX"
  subnet_id     = aws_subnet.Project-IV-VPC-Pub-sbn.id
  vpc_security_group_ids = [aws_security_group.Project-IV-SG.id]
  user_data = <<-EOF
      #!/bin/bash
      cp /etc/sysctl.conf /root/sysctl.conf_backup
      cat <<EOT> /etc/sysctl.conf
      vm.max_map_count=262144
      fs.file-max=65536
      ulimit -n 65536
      ulimit -u 4096
      EOT
      cp /etc/security/limits.conf /root/sec_limit.conf_backup
      cat <<EOT> /etc/security/limits.conf
      sonarqube   -   nofile   65536
      sonarqube   -   nproc    409
      EOT

      sudo apt-get update -y
      sudo apt-get install openjdk-11-jdk -y
      sudo update-alternatives --config java

      java -version

      sudo apt update
      wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -

      sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
      sudo apt install postgresql postgresql-contrib -y
      #sudo -u postgres psql -c "SELECT version();"
      sudo systemctl enable postgresql.service
      sudo systemctl start  postgresql.service
      sudo echo "postgres:admin123" | chpasswd
      runuser -l postgres -c "createuser sonar"
      sudo -i -u postgres psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'admin123';"
      sudo -i -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
      sudo -i -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube to sonar;"
      systemctl restart  postgresql
      #systemctl status -l   postgresql
      netstat -tulpena | grep postgres
      sudo mkdir -p /sonarqube/
      cd /sonarqube/
      sudo curl -O https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-8.3.0.34182.zip
      sudo apt-get install zip -y
      sudo unzip -o sonarqube-8.3.0.34182.zip -d /opt/
      sudo mv /opt/sonarqube-8.3.0.34182/ /opt/sonarqube
      sudo groupadd sonar
      sudo useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
      sudo chown sonar:sonar /opt/sonarqube/ -R
      cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup
      cat <<EOT> /opt/sonarqube/conf/sonar.properties
      sonar.jdbc.username=sonar
      sonar.jdbc.password=admin123
      sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
      sonar.web.host=0.0.0.0
      sonar.web.port=9000
      sonar.web.javaAdditionalOpts=-server
      sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
      sonar.log.level=INFO
      sonar.path.logs=logs
      EOT

      cat <<EOT> /etc/systemd/system/sonarqube.service
      [Unit]
      Description=SonarQube service
      After=syslog.target network.target

      [Service]
      Type=forking

      ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
      ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

      User=sonar
      Group=sonar
      Restart=always

      LimitNOFILE=65536
      LimitNPROC=4096


      [Install]
      WantedBy=multi-user.target
      EOT

      systemctl daemon-reload
      systemctl enable sonarqube.service
      #systemctl start sonarqube.service
      #systemctl status -l sonarqube.service
      apt-get install nginx -y
      rm -rf /etc/nginx/sites-enabled/default
      rm -rf /etc/nginx/sites-available/default
      cat <<EOT> /etc/nginx/sites-available/sonarqube
      server{
          listen      80;
          server_name sonarqube.groophy.in;

          access_log  /var/log/nginx/sonar.access.log;
          error_log   /var/log/nginx/sonar.error.log;

          proxy_buffers 16 64k;
          proxy_buffer_size 128k;

          location / {
              proxy_pass  http://127.0.0.1:9000;
              proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
              proxy_redirect off;
                    
              proxy_set_header    Host            \$host;
              proxy_set_header    X-Real-IP       \$remote_addr;
              proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
              proxy_set_header    X-Forwarded-Proto http;
          }
      }
      EOT
      ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
      systemctl enable nginx.service
      #systemctl restart nginx.service
      sudo ufw allow 80,9000,9001/tcp

      echo "System reboot in 30 sec"
      sleep 30
      reboot
    EOF
  tags = {
    Name = "SonarQube"
  }
}

# Resource-10: Create an Amazon Linux 2 VM instance and call it "Nexus"
resource "aws_instance" "Nexus" {
  ami           = "ami-0a606d8395a538502"
  instance_type = "t2.medium"
  key_name      = "XXXXXXXXXXXX"
  subnet_id     = aws_subnet.Project-IV-VPC-Pub-sbn.id
  vpc_security_group_ids = [aws_security_group.Project-IV-SG.id]
  user_data = <<-EOF
      #!/bin/bash
      yum install java-1.8.0-openjdk.x86_64 wget -y   
      mkdir -p /opt/nexus/   
      mkdir -p /tmp/nexus/                           
      cd /tmp/nexus/
      NEXUSURL="https://download.sonatype.com/nexus/3/latest-unix.tar.gz"
      wget $NEXUSURL -O nexus.tar.gz
      EXTOUT=`tar xzvf nexus.tar.gz`
      NEXUSDIR=`echo $EXTOUT | cut -d '/' -f1`
      rm -rf /tmp/nexus/nexus.tar.gz
      rsync -avzh /tmp/nexus/ /opt/nexus/
      useradd nexus
      chown -R nexus.nexus /opt/nexus 
      cat <<EOT>> /etc/systemd/system/nexus.service
      [Unit]                                                                          
      Description=nexus service                                                       
      After=network.target                                                            
                                                                        
      [Service]                                                                       
      Type=forking                                                                    
      LimitNOFILE=65536                                                               
      ExecStart=/opt/nexus/$NEXUSDIR/bin/nexus start                                  
      ExecStop=/opt/nexus/$NEXUSDIR/bin/nexus stop                                    
      User=nexus                                                                      
      Restart=on-abort                                                                
                                                                        
      [Install]                                                                       
      WantedBy=multi-user.target                                                      

      EOT

      echo 'run_as_user="nexus"' > /opt/nexus/$NEXUSDIR/bin/nexus.rc
      systemctl daemon-reload
      systemctl start nexus
      systemctl enable nexus

      # Installing Git
      sudo yum install git -y
      ###  
    EOF

  tags = {
    Name = "Nexus"
  }
}

# Resource-11: Create an Amazon Linux 2 VM instance and call it Dev-Env
resource "aws_instance" "Dev-Env" {
  ami           = "ami-0a606d8395a538502"
  instance_type = "t2.medium"
  key_name      = "XXXXXXXXXXXX"
  subnet_id     = aws_subnet.Project-IV-VPC-Pub-sbn.id
  vpc_security_group_ids = [aws_security_group.Project-IV-SG.id]
  user_data = <<-EOF
      #!/bin/bash
  
      # Installing Git
      sudo yum install git -y
      ###  

    EOF

  tags = {
    Name = "Dev-Env"
  }
}

# Resource-12: Create an Amazon Linux 2 VM instance and call it Stage-Env
resource "aws_instance" "Stage-Env" {
  ami           = "ami-0a606d8395a538502"
  instance_type = "t2.medium"
  key_name      = "XXXXXXXXXXXX"
  subnet_id     = aws_subnet.Project-IV-VPC-Pub-sbn.id
  vpc_security_group_ids = [aws_security_group.Project-IV-SG.id]
  user_data = <<-EOF
      #!/bin/bash
  
      # Installing Git
      sudo yum install git -y
      ###  
      
    EOF

  tags = {
    Name = "Stage-Env"
  }
}

# Resource-13: Create an Amazon Linux 2 VM instance and call it Prod-Env
resource "aws_instance" "Prod-Env" {
  ami           = "ami-0a606d8395a538502"
  instance_type = "t2.medium"
  key_name      = "XXXXXXXXXXXX"
  subnet_id     = aws_subnet.Project-IV-VPC-Pub-sbn.id
  vpc_security_group_ids = [aws_security_group.Project-IV-SG.id]
  user_data = <<-EOF
      #!/bin/bash
  
      # Installing Git
      sudo yum install git -y
      ###  
      
    EOF

  tags = {
    Name = "Prod-Env"
  }
}

# Resource-14: Create an Ubuntu 20.04 VM instance and call it "Prometheus"
resource "aws_instance" "Prometheus" {
  ami           = "ami-0ada6d94f396377f2"
  instance_type = "t2.micro"
  key_name      = "XXXXXXXXXXXX"
  subnet_id     = aws_subnet.Project-IV-VPC-Pub-sbn.id
  vpc_security_group_ids = [aws_security_group.Project-IV-SG.id]

  tags = {
    Name = "Prometheus"
  }
}

# Resource-15: Create an Ubuntu 20.04 VM instance and call it "Grafana"
resource "aws_instance" "Grafana" {
  ami           = "ami-0ada6d94f396377f2"
  instance_type = "t2.micro"
  key_name      = "XXXXXXXXXXXX"
  subnet_id     = aws_subnet.Project-IV-VPC-Pub-sbn.id
  vpc_security_group_ids = [aws_security_group.Project-IV-SG.id]

  tags = {
    Name = "Grafana"
  }
}
