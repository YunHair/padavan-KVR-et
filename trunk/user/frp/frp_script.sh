#!/bin/sh
export PATH='/etc/storage/bin:/tmp/frp:/tmp/script:/etc/storage/script:/opt/usr/sbin:/opt/usr/bin:/opt/sbin:/opt/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin'
export LD_LIBRARY_PATH=/lib:/opt/lib
killall frpc frps
mkdir -p /tmp/frp

# 生成INI格式配置文件
cat > "/tmp/frp/myfrpc.ini" <<-\EOF
[common]
server_addr = frps.com
server_port = 7000
token = 12345

[web]
type = http
local_ip = 192.168.2.1
local_port = 80
subdomain = test
EOF

cat > "/tmp/frp/myfrps.ini" <<-\EOF
[common]
bind_port = 7000
token = 12345
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
vhost_http_port = 88
subdomain_host = frps.com
max_pool_count = 50
EOF

frpc_enable=`nvram get frpc_enable`
frps_enable=`nvram get frps_enable`

if [ "$frps_enable" = "1" ] ; then
    /etc/storage/bin/frps -c /tmp/frp/myfrps.ini >/tmp/frps.log 2>&1 &
fi

if [ "$frpc_enable" = "1" ] ; then
    [ "$frps_enable" = "1" ] && sleep 30
    /etc/storage/bin/frpc -c /tmp/frp/myfrpc.ini >/tmp/frpc.log 2>&1 &
fi
