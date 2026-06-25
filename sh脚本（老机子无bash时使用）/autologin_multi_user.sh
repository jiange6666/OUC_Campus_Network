#!/bin/sh
# 中国海洋大学校园网多接口自动登录脚本
# 接口与账号密码必须一一对应，使用几个就配置几个

# ====================== 配置区 ======================
INTERFACES="eth1mac0 eth1mac1"  # 网络接口名称，空格分隔
USERS="123456 123456" # 校园网账号，与接口顺序对应
PASSWORDS="111111 111111"   # 校园网密码，与接口顺序对应
# ===================================================

echo ""
echo "================================="
echo "中国海洋大学校园网登录脚本开始"
echo "================================="
sleep 2

# 获取指定接口的IPv4地址
get_ip() {
    local interface="$1"
    ip addr show "$interface" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1
}

# 获取指定接口的MAC地址（带冒号标准格式）
get_mac() {
    local interface="$1"
    ip link show "$interface" | grep -o 'link/ether [^ ]*' | cut -d' ' -f2
}

# 单次登录执行函数
do_login() {
    local eth="$1"
    local user="$2"
    local pass="$3"
    local ip=$(get_ip "$eth")
    local mac=$(get_mac "$eth")
    # 兼容精简sh环境的随机数生成
    local rand_v=$((1000 + $(awk 'BEGIN{srand(); print int(rand()*9000)}')))

    echo ""
    echo "$eth IP: ${ip:-未获取}"
    echo "$eth MAC: ${mac:-未获取}"

    if [ -n "$ip" ]; then
        echo "正在登录$eth..."
        # 关键修正：--interface 绑定网卡接口名，而非IP地址
        response=$(curl --interface "$ip" --connect-timeout 5 --silent --show-error --insecure \
        "https://xha.ouc.edu.cn:802/eportal/portal/login?callback=dr1003&login_method=1&user_account=${user}&user_password=${pass}&wlan_user_ip=${ip}&wlan_user_mac=${mac}&jsVersion=4.1&terminal_type=1&lang=zh-cn&v=${rand_v}")
        if [ $? -eq 0 ]; then
            echo "登录请求已发送: $response"
        else
            echo "登录请求失败: $response"
        fi
    else
        echo "$eth无IP地址，跳过登录"
    fi
    sleep 5
}

# 第一轮登录
i=0
for eth in $INTERFACES; do
    user=$(echo "$USERS" | cut -d' ' -f$((i+1)))
    pass=$(echo "$PASSWORDS" | cut -d' ' -f$((i+1)))
    do_login "$eth" "$user" "$pass"
    i=$((i+1))
done

sleep 5
echo ""
echo "第二轮登录开始"

# 第二轮重试登录，提升多接口场景成功率
i=0
for eth in $INTERFACES; do
    user=$(echo "$USERS" | cut -d' ' -f$((i+1)))
    pass=$(echo "$PASSWORDS" | cut -d' ' -f$((i+1)))
    do_login "$eth" "$user" "$pass"
    i=$((i+1))
done

sleep 1
echo ""
echo "================================="
echo "登录流程结束"
echo "================================="