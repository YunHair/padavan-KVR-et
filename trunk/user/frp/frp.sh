#!/bin/sh

frpc_enable=`nvram get frpc_enable`
frps_enable=`nvram get frps_enable`
frp_tag=`nvram get frp_tag`
http_username=`nvram get http_username`
user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
github_proxys="$(nvram get github_proxy)"
[ -z "$github_proxys" ] && github_proxys=" "

check_frp () {
	check_net
	result_net=$?
	if [ "$result_net" = "1" ] ;then
		if [ -z "`pidof frpc`" ] && [ "$frpc_enable" = "1" ];then
			frp_start
		fi
		if [ -z "`pidof frps`" ] && [ "$frps_enable" = "1" ];then
			frp_start
		fi
	fi
}

check_net() {
	/bin/ping -c 3 223.5.5.5 -w 5 >/dev/null 2>&1
	if [ "$?" == "0" ]; then
		return 1
	else
		return 2
		logger -t "【Frp】" "检测到互联网未能成功访问,稍后再尝试启动frp"
	fi
}

check_version() {
    local bin_path=$1
    local expected_version=$2
    [ ! -f "$bin_path" ] && return 1
    local current_version="$($bin_path --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
    [ -z "$current_version" ] && return 1
    [ "$current_version" != "$expected_version" ] && return 1
    return 0
}

frp_renum=`nvram get frp_renum`

frp_restart () {
relock="/var/lock/frp_restart.lock"
if [ "$1" = "o" ] ; then
	nvram set frp_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	frp_renum=${frp_renum:-"0"}
	frp_renum=`expr $frp_renum + 1`
	nvram set frp_renum="$frp_renum"
	if [ "$frp_renum" -gt "3" ] ; then
		I=19
		echo $I > $relock
		logger -t "【Frp】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(nvram get frp_renum)" = "0" ] && break
			[ $I -lt 0 ] && break
	 done
		nvram set frp_renum="1"
	fi
	[ -f $relock ] && rm -f $relock
fi
frp_start
}

find_bin() {
frpc=`nvram get frpc_bin`
frps=`nvram get frps_bin`
 	
dirs="/etc/storage/bin
/tmp/frp
/usr/bin"

if [ -z "$frpc" ] ; then
  for dir in $dirs ; do
    if [ -f "$dir/frpc" ] ; then
        frpc="$dir/frpc"
        [ ! -x "$frpc" ] && chmod +x $frpc
        break
    fi
  done
  [ -z "$frpc" ] && frpc="/etc/storage/bin/frpc"
fi
if [ -z "$frps" ] ; then
  for dir in $dirs ; do
    if [ -f "$dir/frps" ] ; then
        frps="$dir/frps"
        [ ! -x "$frps" ] && chmod +x $frps
        break
    fi
  done
  [ -z "$frps" ] && frps="/etc/storage/bin/frps"
fi
}

get_ver() {
	find_bin
	if [ -f "$frpc" ] ; then
 		[ ! -x "$frpc" ] && chmod +x $frps
		frpc_ver="$($frpc --version)"
		if [ -z "$frpc_ver" ] ; then
			frpc_v=""
		else
			frpc_v="frpc-v${frpc_ver}"
		fi
	fi
	if [ -f "$frps" ] ; then
 		[ ! -x "$frps"] && chmod +x $frps
		frps_ver="$($frps --version)"
		if [ -z "$frps_ver" ] ; then
			frps_v=""
		else
			frps_v="frps-v${frps_ver}"
		fi
	fi
	nvram set frp_ver="$frpc_v  $frps_v"
}

get_tag() {
	curltest=`which curl`
	logger -t "【Frp】" "开始获取最新版本..."
    	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
      		tag="$( wget --no-check-certificate -T 5 -t 3 --user-agent "$user_agent" --output-document=-  https://api.github.com/repos/fatedier/frp/releases/latest 2>&1 | grep 'tag_name' | cut -d\" -f4 )"
	 	[ -z "$tag" ] && tag="$( wget --no-check-certificate -T 5 -t 3 --user-agent "$user_agent" --quiet --output-document=-  https://api.github.com/repos/fatedier/frp/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
    	else
      		tag="$( curl -k --connect-timeout 3 --user-agent "$user_agent"  https://api.github.com/repos/fatedier/frp/releases/latest 2>&1 | grep 'tag_name' | cut -d\" -f4 )"
       	[ -z "$tag" ] && tag="$( curl -Lk --connect-timeout 3 --user-agent "$user_agent" -s  https://api.github.com/repos/fatedier/frp/releases/latest  2>&1 | grep 'tag_name' | cut -d\" -f4 )"
        fi
	[ -z "$tag" ] && logger -t "【Frp】" "无法获取最新版本"
	nvram set frp_ver_n=$tag
}

frp_dl () {
	tag="$1"
	newtag="$(echo "$tag" | tr -d 'v' | tr -d ' ')"
	mkdir -p /tmp/frp_dl /etc/storage/bin
	
	logger -t "【Frp】" "开始下载 frp_${newtag}_linux_mipsle.tar.gz 到临时目录/tmp/frp_dl"
	for proxy in $github_proxys; do
		curl -Lko "/tmp/frp_dl/frp_linux_mipsle.tar.gz" "${proxy}https://github.com/fatedier/frp/releases/download/${tag}/frp_${newtag}_linux_mipsle.tar.gz" || \
		wget --no-check-certificate -O "/tmp/frp_dl/frp_linux_mipsle.tar.gz" "${proxy}https://github.com/fatedier/frp/releases/download/${tag}/frp_${newtag}_linux_mipsle.tar.gz"
		
		if [ "$?" = 0 ]; then
			tar -xz -C /tmp/frp_dl -f /tmp/frp_dl/frp_linux_mipsle.tar.gz
			
			if [ "$frpc_enable" = "1" ]; then
				if ! check_version "/etc/storage/bin/frpc" "$newtag"; then
					logger -t "【Frp】" "复制 frpc 到 /etc/storage/bin"
					cp "/tmp/frp_dl/frp_${newtag}_linux_mipsle/frpc" "/etc/storage/bin/frpc"
					chmod +x /etc/storage/bin/frpc
				fi
			fi
			
			if [ "$frps_enable" = "1" ]; then
				if ! check_version "/etc/storage/bin/frps" "$newtag"; then
					logger -t "【Frp】" "复制 frps 到 /etc/storage/bin"
					cp "/tmp/frp_dl/frp_${newtag_linux_mipsle}/frps" "/etc/storage/bin/frps"
					chmod +x /etc/storage/bin/frps
				fi
			fi
			
			rm -rf /tmp/frp_dl/frp_${newtag}_linux_mipsle /tmp/frp_dl/frp_linux_mipsle.tar.gz
			break
		else
			logger -t "【Frp】" "下载失败，请手动下载 ${proxy}https://github.com/fatedier/frp/releases/download/${tag}/frp_${newtag}_linux_mipsle.tar.gz"
		fi
	done
}

frp_start () {
  mkdir -p /etc/storage/bin
  get_tag
  [ -z "$tag" ] && tag="v0.61.0" && logger -t "【Frp】" "使用默认版本 $tag"
  newtag="$(echo "$tag" | tr -d 'v' | tr -d ' ')"

  if [ "$frpc_enable" = "1" ]; then
    if [ ! -f "/etc/storage/bin/frpc" ] || ! check_version "/etc/storage/bin/frpc" "$newtag"; then
      logger -t "【Frp】" "frpc 需要更新，开始下载..."
      frp_dl "$tag"
    fi
  fi

  if [ "$frps_enable" = "1" ]; then
    if [ ! -f "/etc/storage/bin/frps" ] || ! check_version "/etc/storage/bin/frps" "$newtag"; then
      logger -t "【Frp】" "frps 需要更新，开始下载..."
      frp_dl "$tag"
    fi
  fi

  eval /etc/storage/frp_script.sh &
  
  if [ "$frps_enable" = "1" ]; then
    sleep 4
    [ -z "`pidof frps`" ] && logger -t "【Frp】" "frps启动失败, 注意检查端口是否有冲突,程序是否下载完整,10 秒后自动尝试重新启动" && sleep 10 && frp_restart x
    [ ! -z "`pidof frps`" ] && logger -t "【Frp】" "请手动配置【外网 WAN - 端口转发 - 启用手动端口映射】来开启WAN访问"
  fi
  
  if [ "$frpc_enable" = "1" ]; then
    [ "$frps_enable" = "1" ] && sleep 64
    sleep 4
    [ -z "`pidof frpc`" ] && logger -t "【Frp】" "frpc启动失败, 注意检查端口是否有冲突,程序是否下载完整,10 秒后自动尝试重新启动" && sleep 10 && frp_restart x
  fi
  
  if [ "$frps_enable" = "1" ] && [ ! -z "`pidof frps`" ]; then
     mem=$(cat /proc/$(pidof frps)/status | grep -w VmRSS | awk '{printf "%.1f MB", $2/1024}')
     scpu="$(top -b -n1 | grep -E "$(pidof frps)" 2>/dev/null| grep -v grep | awk '{for (i=1;i<=NF;i++) {if ($i ~ /frps/) break; else cpu=i}} END {print $cpu}')"
     logger -t "【Frp】" "frps启动成功" 
     logger -t "【Frp】" "内存占用 ${mem} CPU占用 ${scpu}%"
     frp_restart o
  fi
  
  if [ "$frpc_enable" = "1" ] && [ ! -z "`pidof frpc`" ]; then
     mem=$(cat /proc/$(pidof frpc)/status | grep -w VmRSS | awk '{printf "%.1f MB", $2/1024}')
     ccpu="$(top -b -n1 | grep -E "$(pidof frpc)" 2>/dev/null| grep -v grep | awk '{for (i=1;i<=NF;i++) {if ($i ~ /frpc/) break; else cpu=i}} END {print $cpu}')"
     logger -t "【Frp】" "frpc启动成功" 
     logger -t "【Frp】" "内存占用 ${mem} CPU占用 ${ccpu}%" 
     frp_restart o
  fi
}

frp_close () {
	scriptname=$(basename $0)
	if [ "$frpc_enable" = "0" ]; then
		sed -Ei '/【frpc】|^$/d' /tmp/script/_opt_script_check
		if [ ! -z "`pidof frpc`" ]; then
			killall frpc
			killall -9 frpc frp_script.sh
			[ -z "`pidof frpc`" ] && logger -t "【Frp】" "已停止 frpc"
	    	fi
	fi
	if [ "$frps_enable" = "0" ]; then
		sed -Ei '/【frps】|^$/d' /tmp/script/_opt_script_check
		if [ ! -z "`pidof frps`" ]; then
		killall frps
		killall -9 frps frp_script.sh
		[ -z "`pidof frps`" ] && logger -t "【Frp】" "已停止 frps"
	    fi
	fi
 	if [ ! -z "$scriptname" ] ; then
		eval $(ps -w | grep "$scriptname" | grep -v $$ | grep -v grep | awk '{print "kill "$1";";}')
		eval $(ps -w | grep "$scriptname" | grep -v $$ | grep -v grep | awk '{print "kill -9 "$1";";}')
	fi
}

case $1 in
start)
	frp_start &
	;;
stop)
	frp_close
	;;
C)
	check_frp &
	;;
esac
