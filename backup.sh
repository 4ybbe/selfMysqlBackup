#!/bin/bash

# Configurações
DATA="$(date +'-%u')"
HOST='xyz.com.br'
USER='xyz'
PASSWD='xyz'
PASTAFTP='/cloud/'
PASTAFAIL='/cloud/logfail/'

DB_USER="xyz"
DB_PASS="xyz"

BANCOS=$(mysql -u$DB_USER -p$DB_PASS -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys|_log|_temp)")

for BD in $BANCOS; do
    cd /tmp

    echo "----------------------------------------" >>/tmp/log.txt
    echo "Inicio do backup" >>/tmp/log.txt
    date >>/tmp/log.txt
    echo "Backup do Bd: " $BD >>/tmp/log.txt

    # Dump do banco
    mysqldump -u$DB_USER -p$DB_PASS $BD -f >/tmp/$BD.sql

    if [[ $? != 0 ]]; then
            SUCESSO="Falso"
            FAIL=$BD"fail.txt"
            echo "Falha ao realizar o backup do banco: " $BD >>/tmp/$FAIL
            echo "Falha ao realizar o backup do banco: " $BD >>/tmp/log.txt
            date >> /tmp/log.txt
            date >> /tmp/$FAIL
    else
            # Compactação
            if zip /tmp/$BD$DATA.zip /tmp/$BD.sql; then
                    filesize=$(stat -c %s /tmp/$BD$DATA.zip | awk '{print $1}')
                    mb=$(bc <<<"scale=3; $filesize / 1048576")
                    rm /tmp/$BD.sql

                    echo "Backup do Bd: $BD concluido." >>/tmp/log.txt
                    echo "Tamanho do backup compactado $mb MB" >>/tmp/log.txt
                    SUCESSO="Verdadeiro"
                    date >>/tmp/log.txt
            else
                    SUCESSO="Falso"
                   FAIL=$BD"fail.txt"
                    echo "Falha ao compactar o banco: $BD" >>/tmp/$FAIL
                    echo "Falha ao realizar o backup do banco: $BD" >>/tmp/log.txt
            fi
    fi

    if [[ $SUCESSO = "Verdadeiro" ]]; then
            PASTATMP=$PASTAFTP
            FILE=$BD$DATA.zip
    else
            PASTATMP=$PASTAFAIL
            FILE=$FAIL
    fi

    sshpass -p "$PASSWD" sftp -P 22 -o BatchMode=no "$USER@$HOST" <<END_SCRIPT
      cd "$PASTATMP"
      put "/tmp/$FILE"
      quit
END_SCRIPT

    if [ -f "/tmp/$FILE" ]; then
        rm "/tmp/$FILE"
        echo "Arquivo local $FILE removido." >>/tmp/log.txt
    fi

done
