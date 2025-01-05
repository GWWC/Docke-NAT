#!/bin/bash

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 判断是否为 IPv6 地址
is_ipv6() {
    local ip="$1"
    if [[ "$ip" =~ : ]]; then
        return 0
    else
        return 1
    fi
}

if ! command_exists iptables; then
    echo "错误：未安装 iptables，请安装后再运行脚本。"
    exit 1
fi

if ! command_exists docker; then
    echo "错误：未安装 Docker，请安装后再运行脚本。"
    exit 1
fi

if ! command_exists jq; then
    echo "错误：未安装 jq，请安装后再运行脚本。"
    read -p "是否需要安装 jq（y/n）？" install_jq_choice
    if [ "$install_jq_choice" == "y" ]; then
        apt-get update >/dev/null && apt-get install -y jq >/dev/null
    else
        echo "jq 未安装，脚本无法继续运行。"
        exit 1
    fi
fi

if jq -e '.iptables == false' /etc/docker/daemon.json >/dev/null; then
    echo "Docker 的自动 iptables 配置已禁用。"
else
    echo "正在禁用 Docker 的自动 iptables 配置..."
    jq '. + {"iptables": false}' /etc/docker/daemon.json > /tmp/daemon.json && mv /tmp/daemon.json /etc/docker/daemon.json
    echo "正在重启 Docker 服务..."
    systemctl restart docker
fi

# 显示当前网络接口
ip addr show
echo "请检查以下网络接口名称，并确保接下来输入正确的IP段和接口名称："

read -p "请输入 Docker 网络 IP 段（例如：172.17.0.0/16 或 2001:db8::/32）：" docker_network_ip
read -p "请输入 Docker 桥接接口名称（例如：docker0）：" docker_interface
read -p "请输入主网卡接口名称（例如：eth0）：" main_interface

# 检查并识别 IPv6 或 IPv4
if is_ipv6 "$docker_network_ip"; then
    ip_command="ip6tables"
    echo "检测到IPv6地址，使用 ip6tables 配置..."
else
    ip_command="iptables"
    echo "检测到IPv4地址，使用 iptables 配置..."
fi

# 根据 IP 类型配置相应的 iptables 或 ip6tables 规则
if ! $ip_command -t nat -C POSTROUTING -s "$docker_network_ip" ! -o "$docker_interface" -j MASQUERADE 2>/dev/null; then
    $ip_command -t nat -A POSTROUTING -s "$docker_network_ip" ! -o "$docker_interface" -j MASQUERADE
else
    echo "POSTROUTING 规则已存在，无需重复添加。"
fi

if ! $ip_command -C FORWARD -i "$docker_interface" -o "$main_interface" -j ACCEPT 2>/dev/null; then
    $ip_command -A FORWARD -i "$docker_interface" -o "$main_interface" -j ACCEPT
else
    echo "FORWARD 规则 (docker -> 主网卡) 已存在，无需重复添加。"
fi

if ! $ip_command -C FORWARD -i "$main_interface" -o "$docker_interface" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null; then
    $ip_command -A FORWARD -i "$main_interface" -o "$docker_interface" -m state --state RELATED,ESTABLISHED -j ACCEPT
else
    echo "FORWARD 规则 (主网卡 -> docker) 已存在，无需重复添加。"
fi

echo "$ip_command 规则已成功配置。"

read -p "是否需要将 iptables 规则持久化（y/n）？" persist_choice
if [ "$persist_choice" == "y" ]; then
    if command_exists iptables-save; then
        echo "正在持久化 iptables 规则..."
        if [ "$ip_command" == "iptables" ]; then
            iptables-save > /etc/iptables/rules.v4
        else
            ip6tables-save > /etc/iptables/rules.v6
        fi
        echo "规则已成功持久化。"
    else
        echo "未检测到 iptables-persistent，是否需要安装它？"
        read -p "安装 iptables-persistent（y/n）？" install_choice
        if [ "$install_choice" == "y" ]; then
            apt-get update && apt-get install -y iptables-persistent >/dev/null
            if [ "$ip_command" == "iptables" ]; then
                iptables-save > /etc/iptables/rules.v4
            else
                ip6tables-save > /etc/iptables/rules.v6
            fi
            echo "规则已成功持久化。"
        else
            echo "规则未持久化，请注意重新启动后需要重新配置规则。"
        fi
    fi
else
    echo "规则未持久化，请注意重新启动后需要重新配置规则。"
fi
