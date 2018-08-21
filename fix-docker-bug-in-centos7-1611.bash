#!/bin/bash
perl -i -0pe 's/ExecStart=.*?(\n\S*=)/ExecStart=\/usr\/bin\/dockerd -H unix:\/\/\/var\/run\/docker.sock\1/s' /usr/lib/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker.service 
