# Toolbox (tb)

VPS 常用工具箱，命令 `tb` 一键呼出菜单。Debian 12/13。

## 安装

```bash
curl -fsSL -o tb https://raw.githubusercontent.com/merlin-node/toolbox/main/tb.sh && chmod +x tb && mv tb /usr/local/bin/tb
```

之后输入 `tb` 即可。

> 上面的命令默认以 root 身份执行。如果你用的是普通用户：
> ```bash
> curl -fsSL -o tb https://raw.githubusercontent.com/merlin-node/toolbox/main/tb.sh && chmod +x tb && sudo mv tb /usr/local/bin/tb
> ```

> **DD 后的裸系统没有 curl 也没有 wget？** 先装一下：
> ```bash
> apt update && apt install -y curl
> ```
> 然后跑上面的安装命令。

## 功能

- 系统（更新清理 / 系统信息 / 可疑进程检测 / 端口占用查看 / 结束进程 / 时区 / hostname / sudo 用户）
- 基础工具一键装卸（curl / wget / sudo / nano / htop / tmux / git / 等 12 项）
- 网络优化（BBR + fq 一键启用）
- swap 管理
- Caddy 反代（一键生成 Caddyfile / 自动 HTTPS / 服务管理）
- Docker 管理（容器/镜像/网络/卷交互式管理）
- 网络测试（yabs / NodeQuality / 三网回程 / IP 质量 / 流媒体解锁 等）
- 系统工具 - SSH 管理（改密 / 改端口 / 密钥登录 / 禁 root / fail2ban）
- DNS 管理（IPv4/IPv6 分开管理 / 自动备份 / systemd-resolved 与静态 resolv.conf 自适应 / 解析测试）
- DD 重装系统（Debian / Ubuntu / Alma / Rocky / CentOS / Fedora / Alpine / 自定义；隐藏密码输入 + 装完询问立即重启）

## 卸载

菜单内 `脚本管理 → 卸载脚本`，或直接 `sudo rm /usr/local/bin/tb`。

## License

GPL-3.0

