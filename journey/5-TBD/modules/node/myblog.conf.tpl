<IfModule mod_ssl.c>
      <VirtualHost ${private_ip}:443>
              ServerName ${server_name}
              DocumentRoot /home/ubuntu/myblog
      
              <Directory /home/ubuntu/myblog>
                  Options FollowSymLinks
                  AllowOverride Limit Options FileInfo
                  DirectoryIndex index.html
                  Require all granted
              </Directory>
      
              ErrorLog $$$${APACHE_LOG_DIR}/error.log
              CustomLog $$$${APACHE_LOG_DIR}/access.log combined
      
              SSLEngine on
              SSLCertificateFile /etc/letsencrypt/cert.pem
              SSLCertificateKeyFile /etc/letsencrypt/key.pem
              SSLCertificateChainFile /etc/letsencrypt/issuer.pem
      </VirtualHost>
</IfModule>