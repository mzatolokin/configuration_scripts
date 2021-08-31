#!/bin/bash


container_name="newmailserver"

operating_mode=$1

case $operating_mode in




   dkim) 
    echo "Configurate DKIM"    
    ./setup.sh email add test@futurecomes.net test
    ./setup.sh config dkim
    docker exec $container_name openssl genrsa -out /tmp/docker-mailserver/opendkim/keys/futurecomes.net/mail.private 1024
    docker exec $container_name openssl rsa -in /tmp/docker-mailserver/opendkim/keys/futurecomes.net/mail.private -pubout -out /tmp/docker-mailserver/opendkim/keys/futurecomes.net/public.key
    echo *************
    docker cp $container_name:/tmp/docker-mailserver/opendkim/keys/futurecomes.net/public.key ./public.key
    pablic_key=$(cat public.key)
    echo "Public key: $pablic_key"
    echo *************
    docker-compose restart && echo -n "restarting ok"
    docker exec $container_name rm /etc/opendkim/TrustedHosts
    ;;

    config)
    echo "Configurate Postfix"
    
    docker exec $container_name sed -i '/^smtpd_sasl_auth_enable/a smtpd_sasl_path = /var/mail-state/spool-postfix/private/auth \nsmtpd_sasl_type = dovecot' /etc/postfix/main.cf


    echo "Configurate Dovecot"
    
    docker exec $container_name sed -i '/driver = pam/a   driver = passwd-file \n  args = scheme=SHA1 /etc/dovecot/passwd' /etc/dovecot/conf.d/auth-system.conf.ext
    docker exec $container_name sed -i '/  driver = pam/s/^/#/' /etc/dovecot/conf.d/auth-system.conf.ext
    docker exec $container_name touch /etc/dovecot/passwd
    docker exec $container_name chown dovecot: /etc/dovecot/passwd
    docker exec $container_name chmod -R 777 /etc/dovecot/
    ;;

  user-add)

    if [ -z "$2" ]; then
    echo "Error: invalid parametrs"
    
    else

    user_name=$2
    read -s -p "Enter password: " user_password
    echo "User $user_name added"
   # ./setup.sh email add $user_name $user_password
    user_password_hash=$(docker exec $container_name doveadm pw -s sha1 -p $user_password | cut -d '}' -f2)
    docker exec $container_name su dovecot -s /bin/bash -c "echo $user_name:$user_password_hash >> /etc/dovecot/passwd"
    docker exec $container_name service dovecot stop && service dovecot start
    fi
    ;;

  user-remove)
    if [ -z "$2" ]; then
    echo "Error: invalid parametrs"
    else

    user_name=$2
    echo "Remove $user_name"
    #./setup.sh email del $user_name
    docker exec $container_name su dovecot -s /bin/bash -c "sed -i \"/^$user_name/d\" /etc/dovecot/passwd"
    docker exec $container_name service dovecot stop && service dovecot start
    fi
    ;;

  *)
    echo "Error: invalid parametrs"
    ;;
esac
