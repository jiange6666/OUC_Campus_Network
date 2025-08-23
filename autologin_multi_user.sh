#!/bin/bash

# ====== 可配置路由器多接口，多账号密码，但是接口要和账号一一对应 ==========
INTERFACES=("eth1" "eth0.2" "eth0.3") #例子
USERS=("1234567890" "0987654321" "123123123") #例子
PASSWORDS=("123456" "654321" "000000") #例子
# ===============================================================

echo -e "\n================================="
echo -e "\n中国海洋大学校园网登录脚本开始"
echo -e "\n================================="

sleep 2

get_ip() {
    local interface="$1"
    ip addr show "$interface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1
}

get_mac() {
    local interface="$1"
    ip link show "$interface" | awk '/ether/ {print $2}' | head -n 1 | tr '[:lower:]' '[:upper:]'
}

for ETH in "${INTERFACES[@]}"; do
    IP=$(get_ip "$ETH")
    MAC=$(get_mac "$ETH" | sed 's/://g')
    echo -e "\n$ETH IP: ${IP:-未获取}\n$ETH MAC: ${MAC:-未获取}"

    if [ -n "$IP" ] && [ -n "$MAC" ]; then
        for idx in "${!USERS[@]}"; do
            USER="${USERS[$idx]}"
            PASS="${PASSWORDS[$idx]}"
            RAND_V=$((1000 + RANDOM % 9000))
            echo -e "\n正在登录$ETH，账号$USER..."
            curl --interface "$ETH" --connect-timeout 5 \
              "https://xha.ouc.edu.cn:802/eportal/portal/login?callback=dr1003&login_method=1&user_account=$USER&user_password=$PASS&wlan_user_ip=${IP}&wlan_user_mac=${MAC}&jsVersion=4.1&terminal_type=1&lang=zh-cn&v=${RAND_V}"
            sleep 5
        done
    else
        echo -e "\n$ETH无IP或MAC地址，无法登录"
    fi
done

sleep 1

echo -e "\n================================="
echo -e "\n登录流程结束"