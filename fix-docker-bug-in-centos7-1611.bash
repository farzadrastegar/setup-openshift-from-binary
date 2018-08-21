#!/bin/bash
perl -i -0pe 's/ExecStart=.*?(\n\S*=)/ExecStart=\/usr\/bin\/dockerd -H unix:\/\/\/var\/run\/docker.sock\1/s' /usr/lib/systemd/system/docker.service

systemctl daemon-reload
systemctl restart docker.service 

SCRIPT_FILE='/var/local/restart-docker.sh'
cat << EOF > ${SCRIPT_FILE}
#!/bin/bash
systemctl daemon-reload
systemctl restart docker.service
EOF

chmod 755 ${SCRIPT_FILE}
crontab -l | { cat; echo "@reboot ${SCRIPT_FILE}"; } | crontab -
