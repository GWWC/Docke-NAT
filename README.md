# 脚本的用处
1. **解决 UFW 防火墙无法管理 Docker 网络的问题**
   - Docker 默认会绕过 UFW 防火墙规则，导致无法直接通过 UFW 管理 Docker 网络。本脚本通过关闭自动配置 iptables 功能来解决该问题。
2. **解决关闭 Docker 自动配置 iptables 功能后容器内部无法访问外部网络的问题**
   - 在关闭Docker 的自动配置 iptables 功能后由于Docker无法自己配置iptables规则会导致出现容器内部无法访问外部网络的问题。本脚本在禁用该功能后，手动配置 iptables 规则，确保 Docker 容器可以正常访问外部网络。

# 脚本的原理
1. **禁用 Docker 自动配置 iptables 功能**
   - 修改 `/etc/docker/daemon.json` 文件，设置 `"iptables": false`，关闭 Docker 自动添加 iptables 规则的功能。
   - 重启 Docker 服务以应用更改。

2. **手动配置 iptables 规则解决网络问题**
   - 配置 NAT 规则：通过 `POSTROUTING` 链添加规则，使 Docker 容器流量可以通过主机网络访问外部网络。
   - 配置 FORWARD 规则：
     - 允许 Docker 网络接口与主机主网卡之间的流量转发。
     - 允许主网卡接收 Docker 容器的返回流量。

# 使用方法
1. **运行脚本前的准备**
   - 确保已安装 `iptables` 、`jq` 和 `docker`。
   - 确保用户具有对系统的管理员权限。

2. **执行脚本**
   - 运行脚本时，用户需要提供以下信息：
     - Docker 网络 IP 段（例如：`172.17.0.0/16`）。
     - Docker 桥接接口名称（通常为 `docker0`）。
     - 主机主网卡接口名称（例如：`eth0`）。

3. **持久化规则（可选）**
   - 用户可选择是否将配置的 iptables 规则持久化到系统。
   - 如果选择持久化，脚本会尝试安装 `iptables-persistent`，并保存规则。

## 注意事项
1. 本脚本会直接修改系统的 iptables 规则，请在使用前备份相关配置。
2. 禁用 Docker 自动配置 iptables 功能后，用户需手动管理所有与 Docker 相关的网络规则。
3. 持久化规则时，如果系统未安装 `iptables-persistent`，脚本会提示安装。

## 示例运行
```
bash <(curl -sL https://raw.githubusercontent.com/GWWC/Docke-NAT/main/auto.sh)
```

按照提示输入所需参数即可完成配置。

# 贡献
欢迎对脚本提出建议或改进！

如果觉得本脚本不错的话欢迎为本项目点个小星星（star）
