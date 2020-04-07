#!/bin/bash

print_warn(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
print_info(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
print_error(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
version_lt(){
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; 
}

#copy from 秋水逸冰 ss scripts
if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
fi

function define_install_dir(){
    bash_file=`echo "$0"`                         # 读取脚本文件名称
    print_info "安装目录是"
    install_dir=`tail -n 1 ${bash_file}`          # 读取本脚本最后一行作为安装目录
    print_info $install_dir
    print_warn "回车确认，若需要更改，请输入安装目录的绝对路径"
    read install_dir_choose                       # 读取用户输入安装目录
    if [ "$install_dir_choose" != "" ] ; then
        install_dir=$install_dir_choose           # 安装目录赋值
        echo "${install_dir}" | sed '/^[  ]*$/d'  >> ${bash_file}   #安装目录并保存至脚本文件
    fi
}

function install(){
	cd ${install_dir}
# 配置服务器
    # 获取最新版本编号
	wget https://api.github.com/repos/trojan-gfw/trojan/releases/latest >/dev/null 2>&1
    # >/dev/null 2>&1  https://unix.stackexchange.com/a/119650
	latest_version=`grep tag_name latest| awk -F '[:,"v]' '{print $6}'`
	rm -f latest
    # 下载最新版本
	wget https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
    # 解压最新版本，在trojan文件夹，是服务器运行程序，不可删
	tar xf trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
    # 配置服务器程序，删除默认配置文件
	rm -rf ${install_dir}/trojan/config.json
    # 新建配置文件
	cat > ${install_dir}/trojan/config.json <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": $your_local_port,
    "remote_addr": "127.0.0.1",
    "remote_port": $your_remote_port,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/www/server/panel/vhost/cert/${your_domain}/fullchain.pem",
        "key": "/www/server/panel/vhost/cert/${your_domain}/privkey.pem",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF
	# 增加启动脚本	
	trojan_app="${install_dir}/trojan/trojan"
	trojan_pid="${install_dir}/trojan/trojan.pid"
	trojan_conf="${install_dir}/trojan/config.json"
	cat > ${systempwd}trojan.service <<-EOF

[Unit]  
Description=trojan  
After=network.target  
   
[Service]  
Type=simple  
PIDFile=${trojan_pid}
ExecStart=${trojan_app} -c "${trojan_conf}"
ExecReload=  
ExecStop=kill -9 \$(pidof $trojan_app)  
PrivateTmp=true  
   
[Install]  
WantedBy=multi-user.target

EOF
    # 脚本可执行
	chmod +x ${systempwd}trojan.service
    # 启动trojan服务
    systemctl daemon-reload
	systemctl start trojan.service
	systemctl enable trojan.service


# 配置客户端
    # 准备通用配置文件
    mkdir -p ${install_dir}/trojan-client/common
	cat > ${install_dir}/trojan-client/common/config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": ${your_cli_port},
    "remote_addr": "${your_domain}",
    "remote_port": ${your_local_port},
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "fullchain.pem",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF
	cp /www/server/panel/vhost/cert/${your_domain}/fullchain.pem ${install_dir}/trojan-client/common/fullchain.pem

    # 准备配置客户端
    mkdir -p ${install_dir}/trojan-client/app
    cd ${install_dir}/trojan-client/app
    # 下载客户端
    mv -f ${install_dir}/trojan-${latest_version}-linux-amd64.tar.xz ./trojan-${latest_version}-linux-amd64.tar.xz
    wget https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-win.zip >/dev/null 2>&1
    wget https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-macos.zip >/dev/null 2>&1
    # 配置客户端
    # linux
    cd ${install_dir}/trojan-client
    	tar xf ./app/trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
    cp -rfp common/*  trojan
    mv -f trojan app/trojan-linux
    zip -q -r trojan-linux.zip app/trojan-linux
    # win
    	unzip app/trojan-${latest_version}-win.zip >/dev/null 2>&1
    cp -rfp common/*  trojan
    mv -f trojan app/trojan-win
    zip -q -r trojan-win.zip app/trojan-win
    # macos
    	unzip app/trojan-${latest_version}-macos.zip >/dev/null 2>&1
    cp -rfp ./common/*  trojan
    mv -f trojan app/trojan-macos
    zip -q -r trojan-macos.zip app/trojan-macos
    # android
    cat > ${install_dir}/trojan-client/trojan-android.txt <<-EOF
    客户端下载地址：
        https://github.com/trojan-gfw/igniter/releases
    ---------------------------------------------------
    Remote Address:
        ${your_domain}
    Remote Address:
        ${your_local_port}
    Password:
        ${trojan_passwd}
EOF
    # for browser
    cat > ${install_dir}/trojan-client/browser.txt <<-EOF
    相关github地址：
        https://github.com/FelisCatus/SwitchyOmega
        https://github.com/gfwlist/gfwlist
    ---------------------------------------------------
    step1:安装Switchyomega
        https://github.com/FelisCatus/SwitchyOmega/releases
    step2:配置trojan-proxy
        新建情景模式
        输入名称trojan-proxy
        选择代理服务器
          代理协议socks5
          代理服务器127.0.0.1
          代理端口${your_cli_port}
        应用选项
    step3:配置auto-proxy
        新建情景模式
        输入名称auto-proxy
        选择自动切换模式
          添加规则列表
            选择AutoProxy
            规则列表网址https://cdn.jsdelivr.net/gh/gfwlist/gfwlist@master/gfwlist.txt
            立即更新情景模式
          应用选项
          规则列表规则trojan-proxy
          默认情景模式直接连接
          应用选项
    step4:选择auto-proxy
EOF

    # 删除多余文件
    rm -rf ./app
    
	print_info "======================================================================"
	print_info "Trojan已安装完成，请到下列目录下载trojan客户端，此客户端已配置好所有参数"
	print_info "${install_dir}/trojan-client"
	print_info "======================================================================"
}



function install_trojan(){
    print_info "======================="
    print_info "开始一些必要的准备"
    print_info "请确保安装nginx"
    print_info "请确保建立站点并申请SSL证书"
    print_info "输入 y 继续"
    read user_prepare
    if [ "$user_prepare" != "y" ] ; then
        exit 1
    fi
    print_info "======================="
    print_info "开始一些服务器配置"
    define_install_dir
    print_info "-----------------------"
    print_info "请输入服务器未占用端口"
    print_info "serve port"
    read your_local_port  #443 trojan协议
    your_remote_port="80"
#    print_info "serve remote port"
#    read your_remote_port # 80非trojan协议
    print_info "-----------------------"
    print_info "请输入服务器绑定的域名"
    read your_domain
    print_info "======================="
    print_info "开始一些客户端配置"
    print_info "请输入客户端连接密码"
    read your_password
    trojan_passwd=$your_password
    print_info "-----------------------"
    print_info "请输入客户端代理端口"
    read your_cli_port
    print_info "======================="
    print_info "下载一些必要工具"
    $systemPackage -y install net-tools socat wget unzip zip curl tar >/dev/null 2>&1
    print_info "======================="
    print_info "核对用户配置"

    if test -s /www/server/panel/vhost/cert/${your_domain}/fullchain.pem; then
       print_info "已找到SSL证书"
    else
        print_error "未找到证书，请重新配置"
        exit 1
    fi

if [  ! -d  ${install_dir} ] ; then
    mkdir -p ${install_dir} 
fi

    Port=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w $your_local_port`
if [ -n "$Port" ]; then
    process=`netstat -tlpn | awk -F '[: ]+' '$5=="$your_local_port"{print $9}'`
    print_error "============================================================="
    print_error "检测到$your_local_port端口被占用，占用进程为：${process}，本次安装结束"
    print_error "============================================================="
    exit 1
fi

    real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
if [ $real_addr == $local_addr ] ; then
	print_info "=========================================="
	print_info "       域名解析正常，开始安装trojan"
	print_info "=========================================="
	sleep 1s
        install
else
    print_warn "===================================="
	print_warn "域名解析地址与本VPS IP地址不一致"
	print_warn "若你确认解析成功你可强制脚本继续运行"
	print_warn "===================================="
	read -p "是否强制运行 ?请输入 [Y/n] :" yn
	[ -z "${yn}" ] && yn="y"
	if [[ $yn == [Yy] ]]; then
            print_warn "强制继续运行脚本"
	    sleep 1s
	    install
	else
	    exit 1
	fi
fi
}


function remove_trojan(){
    print_warn "================================"
    print_warn "即将卸载trojan"
    print_warn "================================"
    define_install_dir
    systemctl stop trojan
    systemctl disable trojan
    rm -f ${systempwd}trojan.service
    rm -rf ${install_dir}/trojan*
    systemctl daemon-reload
    print_info "=============="
    print_info "trojan删除完毕"
    print_info "=============="
}


function update_trojan(){
    define_install_dir
    ${install_dir}/trojan/trojan -v 2>trojan.tmp
    curr_version=`cat trojan.tmp | grep "trojan" | awk '{print $4}'`
    wget https://api.github.com/repos/trojan-gfw/trojan/releases/latest >${install_dir}/dev/null 2>&1
    latest_version=`grep tag_name latest| awk -F '[:,"v]' '{print $6}'`
    rm -f latest
    rm -f trojan.tmp
    if version_lt "$curr_version" "$latest_version"; then
        print_info "当前版本$curr_version,最新版本$latest_version,开始升级……"
        mkdir -p ${install_dir}/trojan_update_temp && cd ${install_dir}/trojan_update_temp
        wget https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
        tar xf trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
        mv ./trojan/trojan ${install_dir}/trojan/
        cd .. && rm -rf trojan_update_temp
        systemctl daemon-reload
        systemctl restart trojan
	${install_dir}/trojan/trojan -v 2>trojan.tmp
	print_info "trojan升级完成，当前版本：`cat trojan.tmp | grep "trojan" | awk '{print $4}'`"
	rm -f trojan.tmp
    else
        print_info "当前版本$curr_version,最新版本$latest_version,无需升级"
    fi
}

function config_bbr(){
    define_install_dir
    mkdir -p ${install_dir}/bbr
    cd ${install_dir}/bbr
    wget "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" 
    chmod +x tcp.sh 
    ./tcp.sh
}

start_menu(){
    clear
    print_info " ======================================="
    print_info " 介绍：一键安装trojan      "
    print_info " 系统：centos7+/debian9+/ubuntu16.04+"
    print_info " 原作者：www.atrandys.com              "
    print_info " 声明："
    print_warn " *请不要在任何生产环境使用此脚本"
    print_warn " *若是第二次使用脚本，请先执行卸载trojan"
    print_info " ======================================="
    echo
    print_info  " 1. 安装trojan"
    print_warn  " 2. 卸载trojan"
    print_info  " 3. 升级trojan"
    print_info  " 4. 配置BBR加速"
    print_info  " 5. 重启trojan"
    print_info  " 6. 停止trojan"
    print_info  " 7. 开启trojan"
    print_info  " 8. 输出信息"
    print_info  " 0. 退出脚本"
    echo
    read -p "请输入数字 :" num
    case "$num" in
    1)
    install_trojan
    ;;
    2)
    remove_trojan 
    ;;
    3)
    update_trojan 
    ;;
    4)
    config_bbr
    ;;
    5)
    systemctl daemon-reload
    systemctl restart trojan
    ;;
    6)
    systemctl daemon-reload
    systemctl stop trojan
    ;;
    7)
    systemctl daemon-reload
    systemctl start trojan
    ;;
    8)
    systemctl daemon-reload
    systemctl status trojan -l
    echo $install_dir/trojan/config.json
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    print_error "请输入正确数字"
    sleep 1s
    start_menu
    ;;
    esac
}

start_menu

exit 0


# 最后一行是用户安装目录，请勿添加多余空行或其他字段
echo
/www/wwwroot/trojan
