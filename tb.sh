#!/usr/bin/env bash
# =============================================================================
# Toolbox Script v1.0 By Merlin
# VPS 常用工具箱 (Debian 12/13)
# 调用:    tb
# 安装:    wget -O tb https://raw.githubusercontent.com/merlin-node/toolbox/main/tb.sh && chmod +x tb && sudo mv tb /usr/local/bin/tb
# =============================================================================

set -o pipefail

SCRIPT_VERSION="1.0"
SCRIPT_AUTHOR="Merlin"
SCRIPT_UPDATE_URL="https://raw.githubusercontent.com/merlin-node/toolbox/main/tb.sh"
TB_SCRIPT_PATH="/usr/local/bin/tb"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

# =============================================================================
# 通用输出
# =============================================================================
msg()  { echo -e "${GREEN}[*]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[x]${NC} $*"; }
ok()   { echo -e "${GREEN}[成功]${NC} $*"; }

term_width() {
    local w
    w=$(tput cols 2>/dev/null || echo 60)
    (( w < 40 )) && w=40
    (( w > 80 )) && w=80
    echo "$w"
}

hr() {
    local w; w=$(term_width)
    printf "${BLUE}%${w}s${NC}\n" '' | tr ' ' '='
}

sec() {
    local title="$1" w side_eq
    w=$(term_width)
    local bytes chars non_ascii_chars ascii_chars visual
    bytes=$(printf '%s' " ${title} " | wc -c)
    chars=$(printf '%s' " ${title} " | wc -m)
    non_ascii_chars=$(( (bytes - chars) / 2 ))
    ascii_chars=$(( chars - non_ascii_chars ))
    visual=$(( ascii_chars + non_ascii_chars * 2 ))
    side_eq=$(( (w - visual) / 2 ))
    (( side_eq < 3 )) && side_eq=3
    local left right
    left=$(printf "%${side_eq}s" '' | tr ' ' '=')
    right=$(printf "%${side_eq}s" '' | tr ' ' '=')
    echo -e "${BLUE}${left} ${BOLD}${title}${NC}${BLUE} ${right}${NC}"
}

pause() {
    echo
    read -rp "$(echo -e "${CYAN}按回车键继续...${NC}")" _ || true
}

confirm() {
    local prompt="${1:-确认操作?}" default="${2:-N}" ans
    if [[ "$default" =~ ^[Yy]$ ]]; then
        read -rp "$(echo -e "${CYAN}${prompt} [Y/n]: ${NC}")" ans
        ans="${ans:-Y}"
    else
        read -rp "$(echo -e "${CYAN}${prompt} [y/N]: ${NC}")" ans
        ans="${ans:-N}"
    fi
    [[ "$ans" =~ ^[Yy]$ ]]
}

need_root() {
    [[ $EUID -eq 0 ]] || { err "请用 root 运行"; exit 1; }
}

check_debian() {
    [[ -f /etc/os-release ]] || { err "无法识别系统"; exit 1; }
    . /etc/os-release
    if [[ "$ID" != "debian" ]]; then
        warn "本脚本仅在 Debian 12/13 测试过，当前: $ID $VERSION_ID"
        confirm "仍要继续?" N || exit 0
    fi
}

# =============================================================================
# Banner
# =============================================================================
show_banner() {
    local sys_ver kernel_ver uptime_str mem_str disk_str
    sys_ver=$(. /etc/os-release && echo "${PRETTY_NAME}")
    kernel_ver=$(uname -r)
    uptime_str=$(uptime -p 2>/dev/null | sed 's/^up //')
    mem_str=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
    disk_str=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')

    local title="Toolbox Script v${SCRIPT_VERSION} By ${SCRIPT_AUTHOR}"
    local w side_eq bytes chars non_ascii_chars ascii_chars visual
    w=$(term_width)
    bytes=$(printf '%s' " ${title} " | wc -c)
    chars=$(printf '%s' " ${title} " | wc -m)
    non_ascii_chars=$(( (bytes - chars) / 2 ))
    ascii_chars=$(( chars - non_ascii_chars ))
    visual=$(( ascii_chars + non_ascii_chars * 2 ))
    side_eq=$(( (w - visual) / 2 ))
    (( side_eq < 3 )) && side_eq=3
    local left right
    left=$(printf "%${side_eq}s" '' | tr ' ' '=')
    right=$(printf "%${side_eq}s" '' | tr ' ' '=')
    echo -e "${GREEN}${left} ${BOLD}${title}${NC}${GREEN} ${right}${NC}"
    echo
    echo -e "  系统: ${sys_ver}   内核: ${kernel_ver}"
    echo -e "  运行: ${uptime_str}"
    echo -e "  内存: ${mem_str}   磁盘: ${disk_str}"
    hr
}

# =============================================================================
# 1. 系统管理
# =============================================================================
sys_update_clean() {
    clear; show_banner
    sec "系统更新清理"
    msg "更新软件源..."
    apt-get update -y
    msg "升级已安装包..."
    apt-get upgrade -y
    msg "清理无用依赖..."
    apt-get autoremove --purge -y
    msg "清理 apt 缓存..."
    apt-get clean
    msg "清理 journal 日志（保留 7 天）..."
    journalctl --vacuum-time=7d >/dev/null 2>&1 || true
    msg "清理旧内核..."
    local current
    current=$(uname -r)
    dpkg -l 'linux-image-*' 2>/dev/null | awk '/^ii/{print $2}' \
        | grep -v "$current" | grep -v "linux-image-generic" \
        | xargs -r apt-get purge -y 2>/dev/null || true
    ok "系统已更新并清理"
    pause
}

menu_system() {
    while :; do
        clear; show_banner
        sec "系统"
        echo -e "  ${BOLD}── 系统信息查询 ──${NC}"
        echo "  1) 系统更新清理"
        echo "  2) 系统概览"
        echo "  3) 实时进程监控 (Top 10)"
        echo "  4) 可疑进程检测 (防挖矿)"
        echo "  5) htop 交互监控"
        echo
        echo -e "  ${BOLD}── 基础配置 ──${NC}"
        echo "  6) 时区设置          当前: $(timedatectl 2>/dev/null | awk '/Time zone/{print $3}')"
        echo "  7) hostname 修改     当前: $(hostname)"
        echo "  8) 添加 sudo 用户"
        echo
        echo "  0) 返回上一页"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择 [0-8]: ${NC}")" c
        case "$c" in
            1) sys_update_clean ;;
            2) sys_info_overview; pause ;;
            3) sys_info_top; pause ;;
            4) sys_info_suspicious ;;
            5)
                if command -v htop >/dev/null 2>&1; then
                    htop
                else
                    warn "htop 未安装，请先在「基础工具」里安装"
                    sleep 2
                fi
                ;;
            6) cfg_timezone; pause ;;
            7) cfg_hostname; pause ;;
            8) cfg_adduser; pause ;;
            0|"") return ;;
            *) err "无效"; sleep 1 ;;
        esac
    done
}

sys_info_overview() {
    clear; show_banner
    sec "系统概览"
    echo -e "  ${CYAN}系统:${NC}    $(. /etc/os-release && echo "$PRETTY_NAME")"
    echo -e "  ${CYAN}内核:${NC}    $(uname -r)"
    echo -e "  ${CYAN}架构:${NC}    $(uname -m)"
    echo -e "  ${CYAN}主机名:${NC}  $(hostname)"
    echo -e "  ${CYAN}运行:${NC}    $(uptime -p 2>/dev/null | sed 's/^up //')"
    echo -e "  ${CYAN}负载:${NC}    $(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')"
    echo
    echo -e "  ${CYAN}CPU:${NC}     $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ //')"
    echo -e "  ${CYAN}核心:${NC}    $(nproc) 核"
    echo
    echo -e "  ${CYAN}内存使用:${NC}"
    free -h | sed 's/^/    /'
    echo
    echo -e "  ${CYAN}磁盘使用:${NC}"
    df -hT -x tmpfs -x devtmpfs | sed 's/^/    /'
    echo
    echo -e "  ${CYAN}网卡 IP:${NC}"
    ip -4 addr show scope global | awk '/inet/ {print "    " $NF, $2}'
    ip -6 addr show scope global 2>/dev/null | awk '/inet6/ {print "    " $NF, $2}' | head -3
    echo
    if command -v vnstat >/dev/null 2>&1; then
        echo -e "  ${CYAN}本月流量:${NC}"
        vnstat -m 2>/dev/null | tail -5 | sed 's/^/    /'
    fi
    hr
}

sys_info_top() {
    clear; show_banner
    sec "实时进程监控 (Top 10)"
    echo -e "  ${CYAN}CPU 占用 Top 10:${NC}"
    ps aux --sort=-%cpu | head -11 | awk 'NR==1 {printf "    %-8s %-6s %-6s %s\n", "USER", "PID", "CPU%", "COMMAND"} NR>1 {printf "    %-8s %-6s %-6s %s\n", $1, $2, $3, substr($0, index($0,$11))}' | cut -c1-100
    echo
    echo -e "  ${CYAN}内存占用 Top 10:${NC}"
    ps aux --sort=-%mem | head -11 | awk 'NR==1 {printf "    %-8s %-6s %-6s %s\n", "USER", "PID", "MEM%", "COMMAND"} NR>1 {printf "    %-8s %-6s %-6s %s\n", $1, $2, $4, substr($0, index($0,$11))}' | cut -c1-100
    hr
}

# 可疑进程检测
sys_info_suspicious() {
    while :; do
        clear; show_banner
        sec "可疑进程检测"
        echo -e "  ${YELLOW}扫描挖矿木马常见特征...${NC}"
        echo

        # 已知挖矿程序名（部分匹配）
        local miners="xmrig|minerd|kdevtmpfsi|kinsing|cpuminer|ethminer|sysupdate|networkservice|kthrotlds|x11miner|monero"
        # 可疑路径
        local susp_paths="^/tmp/|^/dev/shm/|^/var/tmp/|^/run/user/"

        local -a SUSP_PIDS=()
        local -a SUSP_INFO=()

        # 扫描所有进程
        while IFS= read -r line; do
            local pid cpu cmd exe reason
            pid=$(echo "$line" | awk '{print $2}')
            cpu=$(echo "$line" | awk '{print $3}')
            cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')
            [[ -z "$pid" || "$pid" == "PID" ]] && continue

            exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null)
            reason=""

            # 1) 名称匹配
            if echo "$cmd" | grep -qE "$miners"; then
                reason="挖矿程序名"
            fi
            # 2) 路径可疑
            if [[ -n "$exe" ]] && echo "$exe" | grep -qE "$susp_paths"; then
                reason="${reason:+$reason + }可疑路径($exe)"
            fi
            # 3) 高 CPU 且路径在 /tmp 等
            if awk -v c="$cpu" 'BEGIN{exit !(c+0 > 80)}' && [[ -n "$exe" ]] \
               && echo "$exe" | grep -qE "$susp_paths"; then
                reason="${reason:+$reason + }CPU高(${cpu}%)+可疑路径"
            fi

            if [[ -n "$reason" ]]; then
                SUSP_PIDS+=("$pid")
                SUSP_INFO+=("$cmd|$cpu|$exe|$reason")
            fi
        done < <(ps aux 2>/dev/null | tail -n +2)

        if [[ ${#SUSP_PIDS[@]} -eq 0 ]]; then
            ok "未发现明显可疑进程"
        else
            echo -e "  ${RED}发现 ${#SUSP_PIDS[@]} 个可疑进程:${NC}"
            echo
            printf "    %-4s %-7s %-6s %s\n" "编号" "PID" "CPU%" "命令/原因"
            local i=0
            for info in "${SUSP_INFO[@]}"; do
                ((i++))
                local cmd cpu exe reason
                IFS='|' read -r cmd cpu exe reason <<< "$info"
                printf "    ${YELLOW}%-4s${NC} %-7s %-6s %s\n" "$i)" "${SUSP_PIDS[$((i-1))]}" "$cpu" "$(echo "$cmd" | cut -c1-50)"
                printf "    %-4s %-7s %-6s ${RED}原因: %s${NC}\n" "" "" "" "$reason"
                [[ -n "$exe" ]] && printf "    %-4s %-7s %-6s 路径: %s\n" "" "" "" "$exe"
                echo
            done
        fi

        # 检查可疑 cron
        echo -e "  ${CYAN}可疑 cron 任务:${NC}"
        local cron_susp
        cron_susp=$(grep -rE "curl.*\|.*sh|wget.*\|.*sh|/tmp/|/dev/shm/" \
            /etc/cron.* /var/spool/cron/ /etc/crontab 2>/dev/null | head -5)
        if [[ -z "$cron_susp" ]]; then
            echo "    （未发现可疑 cron）"
        else
            echo "$cron_susp" | sed 's/^/    /'
        fi

        hr
        if [[ ${#SUSP_PIDS[@]} -gt 0 ]]; then
            echo "  输入编号杀掉对应进程（可多个，空格分隔）"
            echo "  r) 重新扫描"
            echo "  0) 返回"
        else
            echo "  r) 重新扫描"
            echo "  0) 返回"
        fi
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择: ${NC}")" c

        case "$c" in
            0|"") return ;;
            r|R) continue ;;
            *)
                if [[ ${#SUSP_PIDS[@]} -eq 0 ]]; then
                    err "无可操作的进程"; sleep 1; continue
                fi
                # 多编号
                local killed=0
                for n in $c; do
                    if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#SUSP_PIDS[@]} )); then
                        local pid="${SUSP_PIDS[$((n-1))]}"
                        if kill -9 "$pid" 2>/dev/null; then
                            ok "已杀掉 PID $pid"
                            ((killed++))
                        else
                            err "杀 PID $pid 失败（可能已退出）"
                        fi
                    fi
                done
                if (( killed > 0 )); then
                    warn "建议同时检查并清理对应文件（路径见上方），以及 ~/.ssh/authorized_keys"
                fi
                sleep 2
                ;;
        esac
    done
}

# =============================================================================
# 2. 基础工具（kejilion 风格）
# =============================================================================
# 工具定义：name|包名|描述
TOOLS=(
    "curl|curl|下载工具"
    "wget|wget|下载工具"
    "sudo|sudo|超级管理权限工具"
    "nano|nano|文本编辑器（小白友好）"
    "unzip|unzip|ZIP 解压工具"
    "tar|tar|TAR 解压工具"
    "htop|htop|系统监控工具"
    "tmux|tmux|多窗口/后台运行"
    "git|git|版本控制系统"
    "socat|socat|网络通信工具"
    "net-tools|net-tools|netstat / ifconfig"
    "dnsutils|dnsutils|dig / nslookup"
)

tool_installed() {
    local cmd="$1"
    # net-tools / dnsutils 这种包名和命令名不同的，特殊处理
    case "$cmd" in
        net-tools) command -v netstat >/dev/null 2>&1 ;;
        dnsutils)  command -v dig >/dev/null 2>&1 ;;
        *)         command -v "$cmd" >/dev/null 2>&1 ;;
    esac
}

menu_basic_tools() {
    while :; do
        clear; show_banner
        sec "基础工具"
        # 状态网格，两列显示
        local i=0
        for t in "${TOOLS[@]}"; do
            local name pkg desc
            IFS='|' read -r name pkg desc <<< "$t"
            local status
            if tool_installed "$name"; then
                status="${GREEN}[√] 已安装${NC}"
            else
                status="${RED}[x] 未安装${NC}"
            fi
            ((i++))
            if (( i % 2 == 1 )); then
                printf "  %-10s %b" "$name" "$status"
            else
                printf "       %-10s %b\n" "$name" "$status"
            fi
        done
        (( i % 2 == 1 )) && echo  # 收尾换行
        hr
        i=0
        for t in "${TOOLS[@]}"; do
            local name pkg desc
            IFS='|' read -r name pkg desc <<< "$t"
            ((i++))
            printf "  ${BOLD}%2d)${NC}  %-10s %s\n" "$i" "$name" "$desc"
        done
        echo -e "  ${BOLD} 0)${NC}  返回上一页"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择 [0-${#TOOLS[@]}]: ${NC}")" c
        case "$c" in
            0|"") return ;;
            *)
                if [[ "$c" =~ ^[0-9]+$ ]] && (( c >= 1 && c <= ${#TOOLS[@]} )); then
                    local t="${TOOLS[$((c-1))]}"
                    local name pkg desc
                    IFS='|' read -r name pkg desc <<< "$t"
                    if tool_installed "$name"; then
                        if confirm "$name 已安装，是否卸载?" N; then
                            apt-get remove -y "$pkg"
                            ok "$name 已卸载"
                        fi
                    else
                        msg "安装 $name ..."
                        apt-get update -y >/dev/null 2>&1
                        if apt-get install -y "$pkg"; then
                            ok "$name 安装完成"
                        else
                            err "$name 安装失败"
                        fi
                    fi
                    sleep 1
                else
                    err "无效"; sleep 1
                fi
                ;;
        esac
    done
}

# =============================================================================
# 3. 基础配置（拆出来的：时区/hostname/sudo用户进 menu_system，swap 独立）
# =============================================================================

cfg_timezone() {
    clear; show_banner
    sec "时区设置"
    echo -e "  当前时区: ${YELLOW}$(timedatectl 2>/dev/null | awk '/Time zone/{print $3, $4, $5}')${NC}"
    echo -e "  当前时间: ${YELLOW}$(date)${NC}"
    hr
    echo "  1) Asia/Shanghai      上海 (UTC+8)"
    echo "  2) Asia/Hong_Kong     香港 (UTC+8)"
    echo "  3) Asia/Singapore     新加坡 (UTC+8)"
    echo "  4) Asia/Tokyo         东京 (UTC+9)"
    echo "  5) Europe/London      伦敦 (UTC+0)"
    echo "  6) America/New_York   纽约 (UTC-5)"
    echo "  7) America/Los_Angeles 洛杉矶 (UTC-8)"
    echo "  8) UTC                世界协调时"
    echo "  9) 手动输入"
    echo "  0) 返回"
    hr
    local c tz
    read -rp "$(echo -e "${CYAN}请选择 [0-9]: ${NC}")" c
    case "$c" in
        1) tz="Asia/Shanghai" ;;
        2) tz="Asia/Hong_Kong" ;;
        3) tz="Asia/Singapore" ;;
        4) tz="Asia/Tokyo" ;;
        5) tz="Europe/London" ;;
        6) tz="America/New_York" ;;
        7) tz="America/Los_Angeles" ;;
        8) tz="UTC" ;;
        9) read -rp "  时区 (如 Asia/Shanghai): " tz ;;
        0|"") return ;;
        *) err "无效"; return ;;
    esac
    [[ -z "$tz" ]] && return
    if timedatectl set-timezone "$tz" 2>&1; then
        ok "时区已设为 $tz"
        echo -e "  当前时间: ${GREEN}$(date)${NC}"
    else
        err "设置失败"
    fi
}

cfg_swap() {
    while :; do
        clear; show_banner
        sec "swap 管理"
        echo -e "  当前 swap:"
        swapon --show 2>/dev/null | sed 's/^/    /' || echo "    （无）"
        echo
        free -h | sed 's/^/    /'
        hr
        echo "  1) 新建 1G  swap"
        echo "  2) 新建 2G  swap"
        echo "  3) 新建 4G  swap"
        echo "  4) 自定义大小"
        echo "  5) 删除所有 swap 文件 (/swapfile)"
        echo "  0) 返回"
        hr
        local c size
        read -rp "$(echo -e "${CYAN}请选择 [0-5]: ${NC}")" c
        case "$c" in
            1) size=1024 ;;
            2) size=2048 ;;
            3) size=4096 ;;
            4)
                read -rp "  大小 (MB): " size
                [[ "$size" =~ ^[0-9]+$ ]] || { err "无效"; sleep 1; continue; }
                ;;
            5)
                if [[ -f /swapfile ]]; then
                    swapoff /swapfile 2>/dev/null
                    rm -f /swapfile
                    sed -i '\|^/swapfile|d' /etc/fstab
                    ok "已删除 /swapfile"
                else
                    warn "未发现 /swapfile"
                fi
                pause; continue
                ;;
            0|"") return ;;
            *) err "无效"; sleep 1; continue ;;
        esac
        # 创建 swap
        if [[ -f /swapfile ]]; then
            warn "/swapfile 已存在，将先删除再重建"
            swapoff /swapfile 2>/dev/null
            rm -f /swapfile
            sed -i '\|^/swapfile|d' /etc/fstab
        fi
        msg "创建 ${size}M swap..."
        if fallocate -l "${size}M" /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count="$size"; then
            chmod 600 /swapfile
            mkswap /swapfile >/dev/null
            swapon /swapfile
            grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
            ok "swap 已启用"
            free -h | sed 's/^/    /'
        else
            err "创建失败"
        fi
        pause
    done
}

cfg_hostname() {
    clear; show_banner
    sec "hostname 修改"
    echo -e "  当前主机名: ${YELLOW}$(hostname)${NC}"
    hr
    local new
    read -rp "$(echo -e "${CYAN}新主机名（回车取消）: ${NC}")" new
    [[ -z "$new" ]] && return
    local old
    old=$(hostname)
    hostnamectl set-hostname "$new"
    # 同步 /etc/hosts
    if grep -q "127.0.1.1" /etc/hosts; then
        sed -i "s/127.0.1.1.*/127.0.1.1\t$new/" /etc/hosts
    else
        echo -e "127.0.1.1\t$new" >> /etc/hosts
    fi
    ok "主机名已改为 $new"
    warn "重新登录 SSH 后命令提示符才会更新"
}

cfg_adduser() {
    clear; show_banner
    sec "添加 sudo 用户"
    echo -e "  ${CYAN}用途：${NC}"
    echo "    新建一个普通用户并加入 sudo 组。"
    echo "    以后 SSH 用这个普通用户登录，需要 root 权限时用 sudo。"
    echo "    这是比直接 root 登录更安全的标准做法。"
    hr
    if ! command -v sudo >/dev/null 2>&1; then
        warn "sudo 未安装，先在「基础工具」里装上 sudo 再来"
        return
    fi
    local username
    read -rp "$(echo -e "${CYAN}用户名（回车取消）: ${NC}")" username
    [[ -z "$username" ]] && return
    if id "$username" >/dev/null 2>&1; then
        warn "用户 $username 已存在"
        if confirm "把它加入 sudo 组?" Y; then
            usermod -aG sudo "$username"
            ok "$username 已加入 sudo 组"
        fi
        return
    fi
    adduser "$username"
    usermod -aG sudo "$username"
    ok "用户 $username 创建完成并加入 sudo 组"
    echo
    echo -e "  ${CYAN}下一步建议：${NC}"
    echo "    1) 把你的 SSH 公钥复制给这个用户："
    echo "         mkdir -p /home/$username/.ssh"
    echo "         cp ~/.ssh/authorized_keys /home/$username/.ssh/"
    echo "         chown -R $username:$username /home/$username/.ssh"
    echo "         chmod 700 /home/$username/.ssh"
    echo "         chmod 600 /home/$username/.ssh/authorized_keys"
    echo "    2) 在「系统工具 -> SSH 管理」里禁掉 root 密码登录"
}

# =============================================================================
# 4. 网络优化（BBR）
# =============================================================================
current_cc() { sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown"; }
current_qdisc() { sysctl -n net.core.default_qdisc 2>/dev/null || echo "unknown"; }
check_bbr() { [[ "$(current_cc)" == "bbr" ]]; }

menu_network_optim() {
    while :; do
        clear; show_banner
        sec "网络优化"
        echo -e "  当前拥塞算法: ${YELLOW}$(current_cc)${NC}"
        echo -e "  当前 qdisc:    ${YELLOW}$(current_qdisc)${NC}"
        if check_bbr; then
            echo -e "  ${GREEN}[√] BBR 已启用${NC}"
        else
            echo -e "  ${RED}[x] BBR 未启用${NC}"
        fi
        hr
        echo "  1) 一键启用 BBR + fq"
        echo "  2) 关闭 BBR（切回 cubic + fq_codel）"
        echo "  0) 返回上一页"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择 [0-2]: ${NC}")" c
        case "$c" in
            1) enable_bbr; pause ;;
            2) disable_bbr; pause ;;
            0|"") return ;;
            *) err "无效"; sleep 1 ;;
        esac
    done
}

enable_bbr() {
    if ! modprobe tcp_bbr 2>/dev/null && \
       ! grep -q bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
        err "当前内核不支持 BBR (需要 Linux 4.9+)"
        return 1
    fi
    msg "写入 sysctl 配置..."
    sed -i '/^net\.core\.default_qdisc/d;/^net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf
    echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
    echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1
    sleep 1
    if check_bbr; then
        ok "BBR + fq 已启用"
        echo -e "  算法: ${GREEN}$(current_cc)${NC}    qdisc: ${GREEN}$(current_qdisc)${NC}"
    else
        err "启用失败"
    fi
}

disable_bbr() {
    msg "切回 cubic + fq_codel..."
    sed -i '/^net\.core\.default_qdisc/d;/^net\.ipv4\.tcp_congestion_control/d' /etc/sysctl.conf
    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
    sysctl -w net.core.default_qdisc=fq_codel >/dev/null 2>&1
    ok "已切回 $(current_cc) / $(current_qdisc)"
}

# =============================================================================
# 5. Caddy 反代（从 ca 脚本整合）
# =============================================================================
CADDYFILE="/etc/caddy/Caddyfile"
CADDY_META_DIR="/etc/caddy/.meta"
CADDY_META_FILE="${CADDY_META_DIR}/current"
CADDY_LOG_DIR="/var/log/caddy"

caddy_installed() { command -v caddy >/dev/null 2>&1; }

caddy_version_str() {
    caddy version 2>/dev/null | awk '{print $1}' | head -1
}

caddy_install() {
    if caddy_installed; then
        return 0
    fi
    msg "安装依赖..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null 2>&1

    msg "添加 Caddy 官方源..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
        | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg 2>/dev/null
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
        > /etc/apt/sources.list.d/caddy-stable.list 2>/dev/null

    msg "安装 Caddy..."
    apt-get update -y >/dev/null 2>&1
    apt-get install -y caddy
    mkdir -p "$CADDY_LOG_DIR" "$CADDY_META_DIR"
    ok "Caddy 安装完成"
}

caddy_uninstall() {
    clear; show_banner
    sec "${RED}卸载 Caddy${NC}"
    echo "  将删除: Caddy 程序、配置 /etc/caddy、日志 /var/log/caddy"
    echo
    confirm "确认卸载？" N || return
    systemctl stop caddy 2>/dev/null
    systemctl disable caddy 2>/dev/null
    apt-get purge -y caddy >/dev/null 2>&1
    rm -rf /etc/caddy "$CADDY_LOG_DIR" /var/lib/caddy
    rm -f /etc/apt/sources.list.d/caddy-stable.list
    ok "Caddy 已卸载"
}

caddy_check_port() {
    local ip="$1" port="$2"
    case "$ip" in
        127.0.0.1|localhost|::1) ;;
        *) return 0 ;;
    esac
    local listener
    listener=$(ss -tlnp 2>/dev/null | awk -v p=":$port" '$4 ~ p"$" {print; exit}')
    if [[ -z "$listener" ]]; then
        warn "本机端口 ${port} 当前无服务监听"
        echo -e "  ${YELLOW}Caddy 反代过去会返回错误，请先启动后端服务${NC}"
        echo
        read -rp "$(echo -e "${CYAN}仍要继续? [y/N]: ${NC}")" go
        [[ "$go" =~ ^[Yy]$ ]] || return 1
    else
        local proc
        proc=$(echo "$listener" | grep -oP '"\K[^"]+' | head -1)
        echo -e "  ${GREEN}[√]${NC} 后端服务已监听：${proc:-unknown} on :${port}"
    fi
    return 0
}

caddy_write_apply() {
    local svc="$1" domain="$2" ip="$3" port="$4" timeout="$5"
    mkdir -p "$(dirname "$CADDYFILE")" "$CADDY_META_DIR" "$CADDY_LOG_DIR"
    cat > "$CADDYFILE" << EOF
# 由 tb 工具生成，元数据存于 ${CADDY_META_FILE}
${domain} {
    log {
        output file ${CADDY_LOG_DIR}/${svc}.log {
            roll_size 10mb
            roll_keep 5
        }
    }

    reverse_proxy ${ip}:${port} {
        transport http {
            read_timeout ${timeout}s
            write_timeout ${timeout}s
        }

        header_up Host {upstream_hostport}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
}
EOF
    cat > "$CADDY_META_FILE" << EOF
CADDY_SVC=${svc}
CADDY_DOMAIN=${domain}
CADDY_BACKEND_IP=${ip}
CADDY_BACKEND_PORT=${port}
CADDY_TIMEOUT=${timeout}
EOF
    echo
    msg "校验配置..."
    if ! caddy validate --config "$CADDYFILE" --adapter caddyfile >/dev/null 2>&1; then
        err "配置校验失败"
        caddy validate --config "$CADDYFILE" --adapter caddyfile 2>&1 | sed 's/^/  /'
        return 1
    fi
    ok "校验通过"
    msg "应用配置..."
    systemctl enable caddy >/dev/null 2>&1 || true
    if systemctl is-active --quiet caddy; then
        systemctl reload caddy
        ok "Caddy 已重载"
    else
        systemctl start caddy
        ok "Caddy 已启动"
    fi
}

caddy_load_meta() {
    [[ -f "$CADDY_META_FILE" ]] || return 1
    # shellcheck disable=SC1090
    source "$CADDY_META_FILE"
    # 兼容旧字段名（早期版本写的 SVC_NAME / DOMAIN 等没前缀的）
    [[ -z "${CADDY_SVC:-}"          && -n "${SVC_NAME:-}"     ]] && CADDY_SVC="$SVC_NAME"
    [[ -z "${CADDY_DOMAIN:-}"       && -n "${DOMAIN:-}"       ]] && CADDY_DOMAIN="$DOMAIN"
    [[ -z "${CADDY_BACKEND_IP:-}"   && -n "${BACKEND_IP:-}"   ]] && CADDY_BACKEND_IP="$BACKEND_IP"
    [[ -z "${CADDY_BACKEND_PORT:-}" && -n "${BACKEND_PORT:-}" ]] && CADDY_BACKEND_PORT="$BACKEND_PORT"
    [[ -z "${CADDY_TIMEOUT:-}"      && -n "${TIMEOUT:-}"      ]] && CADDY_TIMEOUT="$TIMEOUT"
    return 0
}

caddy_menu_add() {
    clear; show_banner
    sec "生成 Caddyfile"
    if [[ -f "$CADDYFILE" ]] && caddy_load_meta; then
        echo -e "  ${YELLOW}已存在配置${NC}"
        echo
        echo "  服务:     ${CADDY_SVC}"
        echo "  域名:     ${CADDY_DOMAIN}"
        echo "  后端:     ${CADDY_BACKEND_IP}:${CADDY_BACKEND_PORT}"
        echo
        echo -e "  ${YELLOW}继续将覆盖现有配置${NC}"
        hr
        read -rp "$(echo -e "${CYAN}是否继续? [y/N]: ${NC}")" go
        [[ "$go" =~ ^[Yy]$ ]] || return
        echo
    fi
    local svc domain ip port timeout
    read -rp "$(echo -e "${CYAN}服务名称（用于日志文件名，例如 myapp）: ${NC}")" svc
    [[ -z "$svc" ]] && { err "服务名称不能为空"; pause; return; }
    read -rp "$(echo -e "${CYAN}域名（例如 api.example.com）: ${NC}")" domain
    [[ -z "$domain" ]] && { err "域名不能为空"; pause; return; }
    read -rp "$(echo -e "${CYAN}后端 IP [${NC}127.0.0.1${CYAN}]: ${NC}")" ip
    ip="${ip:-127.0.0.1}"
    read -rp "$(echo -e "${CYAN}后端端口: ${NC}")" port
    [[ -z "$port" ]] && { err "端口不能为空"; pause; return; }
    echo
    if ! caddy_check_port "$ip" "$port"; then
        pause; return
    fi
    echo
    read -rp "$(echo -e "${CYAN}超时(秒) [${NC}300${CYAN}]: ${NC}")" timeout
    timeout="${timeout:-300}"
    if caddy_write_apply "$svc" "$domain" "$ip" "$port" "$timeout"; then
        echo
        hr
        echo -e "  ${GREEN}[√]${NC} 部署完成"
        echo
        echo "  域名:     https://${domain}"
        echo "  后端:     ${ip}:${port}"
        echo "  超时:     ${timeout}s"
        echo "  日志:     ${CADDY_LOG_DIR}/${svc}.log"
        hr
    fi
    pause
}

caddy_menu_view() {
    clear; show_banner
    sec "查看配置"
    if ! caddy_load_meta; then
        warn "尚未生成配置"
        echo -e "  ${YELLOW}请先用「生成 Caddyfile」创建${NC}"
        pause; return
    fi
    echo "  服务名称: ${CADDY_SVC}"
    echo "  域名:     ${CADDY_DOMAIN}"
    echo "  后端 IP:  ${CADDY_BACKEND_IP}"
    echo "  后端端口: ${CADDY_BACKEND_PORT}"
    echo "  超时:     ${CADDY_TIMEOUT}s"
    echo "  日志:     ${CADDY_LOG_DIR}/${CADDY_SVC}.log"
    echo
    if systemctl is-active --quiet caddy; then
        echo -e "  状态:     ${GREEN}running${NC}"
    else
        echo -e "  状态:     ${RED}stopped${NC}"
    fi
    pause
}

caddy_menu_edit() {
    while :; do
        clear; show_banner
        sec "更改配置"
        if ! caddy_load_meta; then
            warn "尚未生成配置"
            pause; return
        fi
        echo "  1) 服务名称   ${CADDY_SVC}"
        echo "  2) 域名       ${CADDY_DOMAIN}"
        echo "  3) 后端 IP    ${CADDY_BACKEND_IP}"
        echo "  4) 后端端口   ${CADDY_BACKEND_PORT}"
        echo "  5) 超时       ${CADDY_TIMEOUT}s"
        echo "  0) 返回上一页"
        hr
        local c new
        read -rp "$(echo -e "${CYAN}选择要修改的项 [0-5]: ${NC}")" c
        case "$c" in
            0|"") return ;;
            1) read -rp "$(echo -e "${CYAN}服务名称 [${NC}${CADDY_SVC}${CYAN}]: ${NC}")" new
               CADDY_SVC="${new:-$CADDY_SVC}" ;;
            2) read -rp "$(echo -e "${CYAN}域名 [${NC}${CADDY_DOMAIN}${CYAN}]: ${NC}")" new
               CADDY_DOMAIN="${new:-$CADDY_DOMAIN}" ;;
            3) read -rp "$(echo -e "${CYAN}后端 IP [${NC}${CADDY_BACKEND_IP}${CYAN}]: ${NC}")" new
               CADDY_BACKEND_IP="${new:-$CADDY_BACKEND_IP}" ;;
            4) read -rp "$(echo -e "${CYAN}后端端口 [${NC}${CADDY_BACKEND_PORT}${CYAN}]: ${NC}")" new
               new="${new:-$CADDY_BACKEND_PORT}"
               if [[ "$new" != "$CADDY_BACKEND_PORT" ]]; then
                   echo
                   if ! caddy_check_port "$CADDY_BACKEND_IP" "$new"; then
                       pause; continue
                   fi
               fi
               CADDY_BACKEND_PORT="$new" ;;
            5) read -rp "$(echo -e "${CYAN}超时(秒) [${NC}${CADDY_TIMEOUT}${CYAN}]: ${NC}")" new
               CADDY_TIMEOUT="${new:-$CADDY_TIMEOUT}" ;;
            *) err "无效"; sleep 1; continue ;;
        esac
        caddy_write_apply "$CADDY_SVC" "$CADDY_DOMAIN" "$CADDY_BACKEND_IP" "$CADDY_BACKEND_PORT" "$CADDY_TIMEOUT"
        pause
    done
}

caddy_view_log() {
    local n="${1:-50}"
    if ! caddy_load_meta; then
        err "尚未生成配置，无日志可看"
        return
    fi
    local f="${CADDY_LOG_DIR}/${CADDY_SVC}.log"
    if [[ -s "$f" ]]; then
        echo -e "  ${BLUE}>>> ${BOLD}${f}${NC}  (最近 ${n} 行)"
        echo
        tail -n "$n" "$f" | sed 's/^/  /'
    else
        warn "Caddy 文件日志为空，改读 systemd 日志"
        echo
        journalctl -u caddy -n "$n" --no-pager | sed 's/^/  /'
    fi
}

caddy_menu_service() {
    while :; do
        clear; show_banner
        sec "Caddy 服务管理"
        local active="${RED}stopped${NC}" enabled="${RED}未启用${NC}"
        local ver
        systemctl is-active --quiet caddy && active="${GREEN}running${NC}"
        systemctl is-enabled --quiet caddy 2>/dev/null && enabled="${GREEN}开机自启${NC}"
        ver=$(caddy_version_str)
        echo -e "  状态: ${active}    自启: ${enabled}    版本: ${ver:-未知}"
        hr
        echo "  1) 启动 Caddy"
        echo "  2) 停止 Caddy"
        echo "  3) 重启 Caddy"
        echo "  4) 查看 systemd 状态"
        echo "  5) 最近 50 行日志"
        echo "  6) 实时跟踪日志 (Ctrl+C 退出)"
        echo "  7) 清空日志文件"
        echo "  8) 更新 Caddy 到最新版"
        echo "  9) 卸载 Caddy"
        echo "  0) 返回上一页"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择 [0-9]: ${NC}")" c
        case "$c" in
            1) systemctl start caddy && ok "已启动"; sleep 1 ;;
            2) systemctl stop caddy && ok "已停止"; sleep 1 ;;
            3) systemctl restart caddy && ok "已重启"; sleep 1 ;;
            4) clear; systemctl status caddy --no-pager -l | head -n 30; pause ;;
            5) clear; caddy_view_log 50; pause ;;
            6) clear; echo "Ctrl+C 退出"
               if caddy_load_meta && [[ -s "${CADDY_LOG_DIR}/${CADDY_SVC}.log" ]]; then
                   tail -f "${CADDY_LOG_DIR}/${CADDY_SVC}.log"
               else
                   journalctl -u caddy -f
               fi ;;
            7) if caddy_load_meta; then
                   : > "${CADDY_LOG_DIR}/${CADDY_SVC}.log"
                   ok "日志已清空"
               else
                   err "无配置可清"
               fi
               sleep 1 ;;
            8) apt-get update -y >/dev/null 2>&1
               apt-get install --only-upgrade -y caddy
               ok "Caddy 已更新至 $(caddy_version_str)"
               pause ;;
            9) caddy_uninstall; pause; return ;;
            0|"") return ;;
            *) err "无效"; sleep 1 ;;
        esac
    done
}

# Caddy 反代主入口（未装时显示安装入口，装了显示完整菜单）
menu_caddy_reverse() {
    while :; do
        clear; show_banner
        sec "Caddy 反代"
        if ! caddy_installed; then
            echo -e "  状态: ${RED}未安装${NC}"
            hr
            echo "  1) 安装 Caddy"
            echo "  0) 返回上一页"
            hr
            local c
            read -rp "$(echo -e "${CYAN}请选择 [0-1]: ${NC}")" c
            case "$c" in
                1) caddy_install; pause ;;
                0|"") return ;;
                *) err "无效"; sleep 1 ;;
            esac
        else
            local active ver domain
            if systemctl is-active --quiet caddy; then
                active="${GREEN}running${NC}"
            else
                active="${RED}stopped${NC}"
            fi
            ver=$(caddy_version_str)
            if caddy_load_meta; then
                domain="$CADDY_DOMAIN"
            else
                domain="${YELLOW}未配置${NC}"
            fi
            echo -e "  caddy: ${ver:-未安装}    状态: ${active}    域名: ${domain}"
            hr
            echo "  1) 添加配置（生成 Caddyfile）"
            echo "  2) 更改配置"
            echo "  3) 查看配置"
            echo "  4) Caddy 服务管理 (含卸载)"
            echo "  0) 返回上一页"
            hr
            local c
            read -rp "$(echo -e "${CYAN}请选择 [0-4]: ${NC}")" c
            case "$c" in
                1) caddy_menu_add ;;
                2) caddy_menu_edit ;;
                3) caddy_menu_view ;;
                4) caddy_menu_service ;;
                0|"") return ;;
                *) err "无效"; sleep 1 ;;
            esac
        fi
    done
}

# =============================================================================
# 6. Docker 管理
# =============================================================================
docker_installed() { command -v docker >/dev/null 2>&1; }

docker_stat_line() {
    if ! docker_installed; then
        echo -e "  ${RED}Docker 未安装${NC}"
        return
    fi
    if ! systemctl is-active --quiet docker; then
        echo -e "  ${YELLOW}Docker 已安装但未运行${NC}"
        return
    fi
    local c i n v
    c=$(docker ps -q 2>/dev/null | wc -l)
    i=$(docker images -q 2>/dev/null | wc -l)
    n=$(docker network ls -q 2>/dev/null | wc -l)
    v=$(docker volume ls -q 2>/dev/null | wc -l)
    echo -e "  ${GREEN}环境已安装${NC}    容器: ${c}    镜像: ${i}    网络: ${n}    卷: ${v}"
}

menu_docker() {
    while :; do
        clear; show_banner
        sec "Docker 管理"
        docker_stat_line
        hr
        echo "  1) 安装 / 更新 Docker"
        echo "  2) 查看 Docker 全局状态"
        echo "  3) 容器管理"
        echo "  4) 镜像管理"
        echo "  5) 网络管理"
        echo "  6) 卷管理"
        echo "  7) 清理无用容器/镜像/网络/卷 (docker system prune)"
        echo "  8) 更换 Docker 源 (daemon.json)"
        echo "  9) 编辑 daemon.json"
        echo "  10) 开启 IPv6"
        echo "  11) 关闭 IPv6"
        echo "  12) 卸载 Docker"
        echo "  0)  返回上一页"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择 [0-12]: ${NC}")" c
        case "$c" in
            1) docker_install; pause ;;
            2) docker_status; pause ;;
            3) docker_containers ;;
            4) docker_images ;;
            5) docker_networks ;;
            6) docker_volumes ;;
            7) docker_prune; pause ;;
            8) docker_change_mirror; pause ;;
            9) docker_edit_daemon; pause ;;
            10) docker_ipv6 on; pause ;;
            11) docker_ipv6 off; pause ;;
            12) docker_uninstall ;;
            0|"") return ;;
            *) err "无效"; sleep 1 ;;
        esac
    done
}

docker_install() {
    msg "安装 Docker..."
    if docker_installed; then
        msg "Docker 已安装，将检查更新"
    fi
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    ok "Docker 安装完成: $(docker --version)"
    ok "Compose: $(docker compose version 2>/dev/null)"
}

docker_status() {
    clear; show_banner
    sec "Docker 全局状态"
    docker_installed || { err "Docker 未安装"; return; }
    echo -e "  ${CYAN}版本:${NC}"
    docker version --format '    Server: {{.Server.Version}}\n    Client: {{.Client.Version}}' 2>/dev/null
    echo
    echo -e "  ${CYAN}系统信息:${NC}"
    docker info 2>/dev/null | grep -E 'Containers|Images|Server Version|Storage Driver|Operating System|Kernel|CPUs|Total Memory' | sed 's/^/    /'
    echo
    echo -e "  ${CYAN}磁盘占用:${NC}"
    docker system df 2>/dev/null | sed 's/^/    /'
    hr
}

# 容器交互管理
docker_containers() {
    while :; do
        clear; show_banner
        sec "Docker 容器管理"
        docker_installed || { err "Docker 未安装"; pause; return; }
        local containers
        mapfile -t containers < <(docker ps -a --format '{{.ID}}|{{.Names}}|{{.Status}}|{{.Image}}' 2>/dev/null)
        if [[ ${#containers[@]} -eq 0 ]]; then
            warn "无容器"
        else
            printf "  %-4s %-12s %-25s %-20s %s\n" "编号" "ID" "名称" "状态" "镜像"
            local i=0
            for line in "${containers[@]}"; do
                ((i++))
                local cid cname cstat cimg
                IFS='|' read -r cid cname cstat cimg <<< "$line"
                local color="$GREEN"
                [[ "$cstat" == Exited* ]] && color="$RED"
                printf "  ${BOLD}%-4s${NC} %-12s %-25s ${color}%-20s${NC} %s\n" \
                    "$i)" "${cid:0:10}" "$(echo "$cname" | cut -c1-23)" "$(echo "$cstat" | cut -c1-18)" "$(echo "$cimg" | cut -c1-30)"
            done
        fi
        hr
        echo "  输入编号: 对该容器操作 (启动/停止/重启/删除/日志/进入)"
        echo "  a) 启动所有  s) 停止所有  r) 重启所有"
        echo "  0) 返回"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择: ${NC}")" c
        case "$c" in
            0|"") return ;;
            a|A) docker start $(docker ps -aq) 2>/dev/null; ok "已启动所有"; sleep 1 ;;
            s|S) docker stop $(docker ps -q) 2>/dev/null; ok "已停止所有"; sleep 1 ;;
            r|R) docker restart $(docker ps -aq) 2>/dev/null; ok "已重启所有"; sleep 1 ;;
            *)
                if [[ "$c" =~ ^[0-9]+$ ]] && (( c >= 1 && c <= ${#containers[@]} )); then
                    local line="${containers[$((c-1))]}"
                    local cid cname rest
                    IFS='|' read -r cid cname rest <<< "$line"
                    docker_container_actions "$cid" "$cname"
                else
                    err "无效"; sleep 1
                fi
                ;;
        esac
    done
}

docker_container_actions() {
    local cid="$1" cname="$2"
    while :; do
        clear; show_banner
        sec "容器: $cname ($cid)"
        echo "  1) 启动"
        echo "  2) 停止"
        echo "  3) 重启"
        echo "  4) 查看日志 (最近 50 行)"
        echo "  5) 实时跟踪日志 (Ctrl+C 退出)"
        echo "  6) 进入容器 shell"
        echo "  7) 查看容器详情 (inspect)"
        echo "  8) 删除容器"
        echo "  0) 返回"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择: ${NC}")" c
        case "$c" in
            1) docker start "$cid" && ok "已启动"; sleep 1 ;;
            2) docker stop "$cid" && ok "已停止"; sleep 1 ;;
            3) docker restart "$cid" && ok "已重启"; sleep 1 ;;
            4) clear; docker logs --tail 50 "$cid"; pause ;;
            5) clear; echo "Ctrl+C 退出"; docker logs -f "$cid" ;;
            6)
                if docker exec "$cid" sh -c 'command -v bash' >/dev/null 2>&1; then
                    docker exec -it "$cid" bash
                else
                    docker exec -it "$cid" sh
                fi
                ;;
            7) clear; docker inspect "$cid" | less; ;;
            8)
                if confirm "确定删除容器 $cname?" N; then
                    docker rm -f "$cid" && ok "已删除"; sleep 1; return
                fi
                ;;
            0|"") return ;;
            *) err "无效"; sleep 1 ;;
        esac
    done
}

# 镜像管理
docker_images() {
    while :; do
        clear; show_banner
        sec "Docker 镜像管理"
        docker_installed || { err "Docker 未安装"; pause; return; }
        local images
        mapfile -t images < <(docker images --format '{{.ID}}|{{.Repository}}:{{.Tag}}|{{.Size}}|{{.CreatedSince}}' 2>/dev/null)
        if [[ ${#images[@]} -eq 0 ]]; then
            warn "无镜像"
        else
            printf "  %-4s %-12s %-40s %-10s %s\n" "编号" "ID" "镜像" "大小" "创建于"
            local i=0
            for line in "${images[@]}"; do
                ((i++))
                local iid iname isize iage
                IFS='|' read -r iid iname isize iage <<< "$line"
                printf "  ${BOLD}%-4s${NC} %-12s %-40s %-10s %s\n" \
                    "$i)" "${iid:0:10}" "$(echo "$iname" | cut -c1-38)" "$isize" "$iage"
            done
        fi
        hr
        echo "  输入编号: 删除该镜像"
        echo "  p) 拉取新镜像  d) 清理悬空镜像 (dangling)"
        echo "  0) 返回"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择: ${NC}")" c
        case "$c" in
            0|"") return ;;
            p|P)
                read -rp "  镜像名 (如 nginx:latest): " img
                [[ -n "$img" ]] && docker pull "$img"
                pause
                ;;
            d|D) docker image prune -f; ok "已清理悬空镜像"; sleep 1 ;;
            *)
                if [[ "$c" =~ ^[0-9]+$ ]] && (( c >= 1 && c <= ${#images[@]} )); then
                    local line="${images[$((c-1))]}"
                    local iid iname rest
                    IFS='|' read -r iid iname rest <<< "$line"
                    if confirm "删除镜像 $iname?" N; then
                        docker rmi "$iid" && ok "已删除"
                        sleep 1
                    fi
                else
                    err "无效"; sleep 1
                fi
                ;;
        esac
    done
}

# 网络管理
docker_networks() {
    while :; do
        clear; show_banner
        sec "Docker 网络管理"
        docker_installed || { err "Docker 未安装"; pause; return; }
        local nets
        mapfile -t nets < <(docker network ls --format '{{.ID}}|{{.Name}}|{{.Driver}}|{{.Scope}}' 2>/dev/null)
        printf "  %-4s %-14s %-20s %-10s %s\n" "编号" "ID" "名称" "驱动" "范围"
        local i=0
        for line in "${nets[@]}"; do
            ((i++))
            local nid nname ndriver nscope
            IFS='|' read -r nid nname ndriver nscope <<< "$line"
            printf "  ${BOLD}%-4s${NC} %-14s %-20s %-10s %s\n" \
                "$i)" "${nid:0:12}" "$nname" "$ndriver" "$nscope"
        done
        hr
        echo "  输入编号: 删除该网络（默认网络无法删除）"
        echo "  c) 创建新网络  i) 查看详情"
        echo "  0) 返回"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择: ${NC}")" c
        case "$c" in
            0|"") return ;;
            c|C)
                read -rp "  网络名: " nname
                read -rp "  驱动 [bridge]: " ndriver
                ndriver="${ndriver:-bridge}"
                [[ -n "$nname" ]] && docker network create --driver "$ndriver" "$nname" && ok "已创建"
                sleep 1
                ;;
            i|I)
                read -rp "  编号: " idx
                if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx >= 1 && idx <= ${#nets[@]} )); then
                    local nid; nid=$(echo "${nets[$((idx-1))]}" | cut -d'|' -f1)
                    docker network inspect "$nid" | less
                fi
                ;;
            *)
                if [[ "$c" =~ ^[0-9]+$ ]] && (( c >= 1 && c <= ${#nets[@]} )); then
                    local line="${nets[$((c-1))]}"
                    local nid nname rest
                    IFS='|' read -r nid nname rest <<< "$line"
                    if confirm "删除网络 $nname?" N; then
                        docker network rm "$nid" && ok "已删除"
                        sleep 1
                    fi
                fi
                ;;
        esac
    done
}

# 卷管理
docker_volumes() {
    while :; do
        clear; show_banner
        sec "Docker 卷管理"
        docker_installed || { err "Docker 未安装"; pause; return; }
        local vols
        mapfile -t vols < <(docker volume ls --format '{{.Name}}|{{.Driver}}' 2>/dev/null)
        printf "  %-4s %-40s %s\n" "编号" "名称" "驱动"
        local i=0
        for line in "${vols[@]}"; do
            ((i++))
            local vname vdrv
            IFS='|' read -r vname vdrv <<< "$line"
            printf "  ${BOLD}%-4s${NC} %-40s %s\n" "$i)" "$vname" "$vdrv"
        done
        hr
        echo "  输入编号: 删除该卷（会删除数据！）"
        echo "  c) 创建新卷  p) 清理未使用的卷"
        echo "  0) 返回"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择: ${NC}")" c
        case "$c" in
            0|"") return ;;
            c|C)
                read -rp "  卷名: " vname
                [[ -n "$vname" ]] && docker volume create "$vname" && ok "已创建"
                sleep 1
                ;;
            p|P)
                if confirm "清理所有未使用的卷？数据将丢失" N; then
                    docker volume prune -f; ok "已清理"
                fi
                sleep 1
                ;;
            *)
                if [[ "$c" =~ ^[0-9]+$ ]] && (( c >= 1 && c <= ${#vols[@]} )); then
                    local line="${vols[$((c-1))]}"
                    local vname rest
                    IFS='|' read -r vname rest <<< "$line"
                    if confirm "删除卷 $vname? 数据将丢失" N; then
                        docker volume rm "$vname" && ok "已删除"
                        sleep 1
                    fi
                fi
                ;;
        esac
    done
}

docker_prune() {
    if confirm "清理所有未使用的容器/镜像/网络/卷？" N; then
        docker system prune -a --volumes -f
        ok "清理完成"
    fi
}

docker_change_mirror() {
    sec "更换 Docker 镜像源"
    echo "  1) 阿里云 (推荐国内)"
    echo "  2) 中科大"
    echo "  3) 网易"
    echo "  4) Docker Hub 官方"
    echo "  0) 返回"
    hr
    local c mirror
    read -rp "$(echo -e "${CYAN}请选择 [0-4]: ${NC}")" c
    case "$c" in
        1) mirror="https://registry.cn-hangzhou.aliyuncs.com" ;;
        2) mirror="https://docker.mirrors.ustc.edu.cn" ;;
        3) mirror="https://hub-mirror.c.163.com" ;;
        4) mirror="" ;;
        0|"") return ;;
        *) err "无效"; return ;;
    esac
    mkdir -p /etc/docker
    # 备份现有配置
    [[ -f /etc/docker/daemon.json ]] && cp /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%Y%m%d-%H%M%S)"
    if [[ -z "$mirror" ]]; then
        echo '{}' > /etc/docker/daemon.json
    else
        cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["${mirror}"]
}
EOF
    fi
    systemctl restart docker
    ok "镜像源已更换"
}

docker_edit_daemon() {
    mkdir -p /etc/docker
    [[ -f /etc/docker/daemon.json ]] || echo '{}' > /etc/docker/daemon.json
    cp /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%Y%m%d-%H%M%S)"
    if ! command -v nano >/dev/null 2>&1; then
        warn "nano 未安装，正在安装..."
        apt-get install -y nano >/dev/null 2>&1
    fi
    nano /etc/docker/daemon.json
    if confirm "重启 Docker 使配置生效？" Y; then
        systemctl restart docker && ok "Docker 已重启"
    fi
}

docker_ipv6() {
    local action="$1"
    mkdir -p /etc/docker
    [[ -f /etc/docker/daemon.json ]] || echo '{}' > /etc/docker/daemon.json
    cp /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date +%Y%m%d-%H%M%S)"
    if ! command -v jq >/dev/null 2>&1; then
        apt-get install -y jq >/dev/null 2>&1
    fi
    if [[ "$action" == "on" ]]; then
        jq '. + {"ipv6": true, "fixed-cidr-v6": "2001:db8:1::/64"}' /etc/docker/daemon.json > /tmp/daemon.json.tmp \
            && mv /tmp/daemon.json.tmp /etc/docker/daemon.json
        ok "已开启 IPv6 (fixed-cidr-v6: 2001:db8:1::/64)"
    else
        jq 'del(.ipv6) | del(."fixed-cidr-v6")' /etc/docker/daemon.json > /tmp/daemon.json.tmp \
            && mv /tmp/daemon.json.tmp /etc/docker/daemon.json
        ok "已关闭 IPv6"
    fi
    systemctl restart docker
}

docker_uninstall() {
    if confirm "卸载 Docker？所有容器和镜像将丢失！输入 YES 确认" N; then
        read -rp "  再次确认，输入 YES: " confirm2
        [[ "$confirm2" != "YES" ]] && { warn "已取消"; pause; return; }
        systemctl stop docker 2>/dev/null
        apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        apt-get autoremove -y
        rm -rf /var/lib/docker /var/lib/containerd /etc/docker
        rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg
        ok "Docker 已卸载"
        pause
    fi
}

# =============================================================================
# 7. 网络测试
# =============================================================================
menu_nettest() {
    while :; do
        clear; show_banner
        sec "网络测试"
        echo "  1) yabs              综合跑分（CPU/内存/磁盘/网络）"
        echo "  2) bench.sh          简易跑分"
        echo "  3) NodeQuality       综合性能+IP质量+流媒体"
        echo "  4) 三网回程路由       测电信/联通/移动回程线路"
        echo "  5) NextTrace         路由追踪"
        echo "  6) 双向 MTR          MTR (本地需自行配合)"
        echo "  7) IP 质量检测       纯净度/解锁/欺诈分"
        echo "  8) 流媒体解锁        Netflix/Disney+/ChatGPT 等"
        echo "  0) 返回上一页"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择 [0-8]: ${NC}")" c
        case "$c" in
            1) clear; curl -sL yabs.sh | bash; pause ;;
            2) clear; wget -qO- bench.sh | bash; pause ;;
            3) clear; bash <(curl -sL https://run.NodeQuality.com); pause ;;
            4) clear; curl https://raw.githubusercontent.com/zhanghanyun/backtrace/main/install.sh -sSf | sh; pause ;;
            5) clear; curl nxtrace.org/nt | bash; nexttrace --help; pause ;;
            6)
                clear
                echo -e "  ${CYAN}本机 → 本地 MTR：${NC}"
                echo "    在本地终端运行: mtr -r -c 10 <VPS_IP>"
                echo
                echo -e "  ${CYAN}本机 → 你提供的 IP 的 MTR：${NC}"
                read -rp "  输入本地公网 IP（或回车跳过）: " target
                if [[ -n "$target" ]]; then
                    command -v mtr >/dev/null 2>&1 || apt-get install -y mtr-tiny
                    mtr -r -c 10 "$target"
                fi
                pause
                ;;
            7) clear; bash <(curl -sL https://IP.Check.Place); pause ;;
            8) clear; bash <(curl -L -s check.unlock.media); pause ;;
            0|"") return ;;
            *) err "无效"; sleep 1 ;;
        esac
    done
}

# =============================================================================
# 8. 系统工具（SSH 管理 + DD）
# =============================================================================
menu_systools() {
    while :; do
        clear; show_banner
        sec "系统工具"
        echo "  1) SSH 管理"
        echo "  2) DD 重装系统 (危险)"
        echo "  0) 返回上一页"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择 [0-2]: ${NC}")" c
        case "$c" in
            1) menu_ssh ;;
            2) menu_dd ;;
            0|"") return ;;
            *) err "无效"; sleep 1 ;;
        esac
    done
}

# SSH 管理子菜单
menu_ssh() {
    while :; do
        clear; show_banner
        sec "SSH 管理"
        local cur_port
        cur_port=$(sshd -T 2>/dev/null | awk '/^port /{print $2}' | head -1)
        local root_login
        root_login=$(sshd -T 2>/dev/null | awk '/^permitrootlogin /{print $2}')
        local pwd_auth
        pwd_auth=$(sshd -T 2>/dev/null | awk '/^passwordauthentication /{print $2}')
        echo -e "  当前 SSH 端口:       ${YELLOW}${cur_port:-22}${NC}"
        echo -e "  Root 登录方式:       ${YELLOW}${root_login}${NC}"
        echo -e "  密码登录:            ${YELLOW}${pwd_auth}${NC}"
        if systemctl is-active --quiet fail2ban 2>/dev/null; then
            echo -e "  fail2ban:           ${GREEN}已启用${NC}"
        else
            echo -e "  fail2ban:           ${RED}未启用${NC}"
        fi
        hr
        echo "  1) 修改 root 密码"
        echo "  2) 修改 SSH 端口"
        echo "  3) 上传公钥 / 启用密钥登录"
        echo "  4) 禁 root 密码登录"
        echo "  5) fail2ban 管理"
        echo "  0) 返回上一页"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择 [0-5]: ${NC}")" c
        case "$c" in
            1) ssh_change_root_pw; pause ;;
            2) ssh_change_port; pause ;;
            3) ssh_setup_key; pause ;;
            4) ssh_disable_root_password; pause ;;
            5) menu_fail2ban ;;
            0|"") return ;;
            *) err "无效"; sleep 1 ;;
        esac
    done
}

ssh_change_root_pw() {
    clear; show_banner
    sec "修改 root 密码"
    passwd root
}

ssh_change_port() {
    clear; show_banner
    sec "修改 SSH 端口"
    local cur new
    cur=$(sshd -T 2>/dev/null | awk '/^port /{print $2}' | head -1)
    echo -e "  当前端口: ${YELLOW}${cur:-22}${NC}"
    read -rp "$(echo -e "${CYAN}新端口 (1-65535，建议 10000+): ${NC}")" new
    [[ -z "$new" ]] && return
    if ! [[ "$new" =~ ^[0-9]+$ ]] || (( new < 1 || new > 65535 )); then
        err "无效端口"; return
    fi
    if ss -tlnp 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${new}$"; then
        err "端口 $new 已被占用"; return
    fi
    # 写入 drop-in
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/99-tb-port.conf << EOF
Port $new
EOF
    if sshd -t 2>&1; then
        systemctl restart ssh
        ok "SSH 端口已改为 $new"
        warn "下次登录用新端口！当前连接保留，谨慎断开前先用新端口测试一下"
    else
        rm -f /etc/ssh/sshd_config.d/99-tb-port.conf
        err "sshd 配置校验失败，已回滚"
    fi
}

ssh_setup_key() {
    clear; show_banner
    sec "上传公钥 / 启用密钥登录"
    echo "  粘贴你的 SSH 公钥（一整行 ssh-rsa AAAA... 或 ssh-ed25519 ...），回车确认："
    local key
    read -r key
    [[ -z "$key" ]] && { warn "已取消"; return; }
    if ! echo "$key" | grep -qE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-)'; then
        err "公钥格式不对"
        return
    fi
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    touch ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    if grep -qF "$key" ~/.ssh/authorized_keys; then
        warn "这把公钥已存在"
    else
        echo "$key" >> ~/.ssh/authorized_keys
        ok "公钥已添加到 ~/.ssh/authorized_keys"
    fi
    # 启用密钥登录
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/99-tb-key.conf << 'EOF'
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
EOF
    if sshd -t; then
        systemctl restart ssh
        ok "密钥登录已启用"
        warn "强烈建议：在新终端测试密钥登录能成功后，再禁用密码登录"
    else
        err "sshd 配置校验失败"
    fi
}

ssh_disable_root_password() {
    clear; show_banner
    sec "禁 root 密码登录"
    warn "执行前请确认："
    echo "  1) 已经能用密钥登录 root，或者"
    echo "  2) 已经创建了 sudo 用户并且可以用密钥/密码登录"
    echo
    confirm "确认继续？" N || return
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/99-tb-noroot.conf << 'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
EOF
    if sshd -t; then
        systemctl restart ssh
        ok "已禁用 root 密码登录 + 全局密码登录"
        warn "现在 SSH 只能用密钥登录"
    else
        rm -f /etc/ssh/sshd_config.d/99-tb-noroot.conf
        err "sshd 配置校验失败，已回滚"
    fi
}

menu_fail2ban() {
    while :; do
        clear; show_banner
        sec "fail2ban 管理"
        if ! command -v fail2ban-client >/dev/null 2>&1; then
            echo -e "  状态: ${RED}未安装${NC}"
            hr
            echo "  1) 安装 fail2ban (默认保护 SSH)"
            echo "  0) 返回上一页"
            hr
            local c
            read -rp "$(echo -e "${CYAN}请选择 [0-1]: ${NC}")" c
            case "$c" in
                1) f2b_install; pause ;;
                0|"") return ;;
                *) err "无效"; sleep 1 ;;
            esac
        else
            local active
            if systemctl is-active --quiet fail2ban; then
                active="${GREEN}运行中${NC}"
            else
                active="${RED}已停止${NC}"
            fi
            local ver
            ver=$(fail2ban-client --version 2>/dev/null | head -1)
            echo -e "  状态: ${active}    版本: ${ver:-未知}"
            # 当前 sshd jail 概况
            local jail_info
            jail_info=$(fail2ban-client status sshd 2>/dev/null)
            if [[ -n "$jail_info" ]]; then
                local cur_banned cur_failed
                cur_banned=$(echo "$jail_info" | awk -F: '/Currently banned/{gsub(/^ +/,"",$2); print $2}')
                cur_failed=$(echo "$jail_info" | awk -F: '/Currently failed/{gsub(/^ +/,"",$2); print $2}')
                echo -e "  SSH jail: 当前封禁 ${YELLOW}${cur_banned:-0}${NC}    当前失败 ${YELLOW}${cur_failed:-0}${NC}"
            fi
            hr
            echo "  1) 查看 SSH jail 状态详情"
            echo "  2) 查看被封禁的 IP 列表"
            echo "  3) 解封指定 IP"
            echo "  4) 重启 fail2ban"
            echo "  5) 编辑配置 (jail.local)"
            echo "  6) 卸载 fail2ban"
            echo "  0) 返回上一页"
            hr
            local c
            read -rp "$(echo -e "${CYAN}请选择 [0-6]: ${NC}")" c
            case "$c" in
                1) clear; fail2ban-client status sshd | sed 's/^/  /'; pause ;;
                2) f2b_list_banned; pause ;;
                3) f2b_unban; pause ;;
                4) systemctl restart fail2ban && ok "已重启"; sleep 1 ;;
                5) f2b_edit; pause ;;
                6) f2b_uninstall; pause ;;
                0|"") return ;;
                *) err "无效"; sleep 1 ;;
            esac
        fi
    done
}

f2b_install() {
    msg "安装 fail2ban..."
    apt-get install -y fail2ban
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
EOF
    systemctl enable fail2ban
    systemctl restart fail2ban
    sleep 1
    if systemctl is-active --quiet fail2ban; then
        ok "fail2ban 已启用 (5 次失败封 1 小时)"
        fail2ban-client status sshd 2>/dev/null | sed 's/^/  /'
    else
        err "启动失败"
        journalctl -u fail2ban -n 20 --no-pager
    fi
}

f2b_list_banned() {
    clear; show_banner
    sec "被封禁的 IP"
    local banned
    banned=$(fail2ban-client status sshd 2>/dev/null | awk -F: '/Banned IP list/{gsub(/^ +/,"",$2); print $2}')
    if [[ -z "$banned" ]]; then
        echo "  （无）"
    else
        echo "$banned" | tr ' ' '\n' | sed 's/^/  /'
    fi
}

f2b_unban() {
    clear; show_banner
    sec "解封 IP"
    read -rp "$(echo -e "${CYAN}输入要解封的 IP (回车取消): ${NC}")" ip
    [[ -z "$ip" ]] && return
    if fail2ban-client set sshd unbanip "$ip" 2>&1 | grep -q '^1$\|unbanned'; then
        ok "$ip 已解封"
    else
        err "解封失败（可能本来就没被封）"
    fi
}

f2b_edit() {
    [[ -f /etc/fail2ban/jail.local ]] || {
        err "jail.local 不存在"; return
    }
    cp /etc/fail2ban/jail.local "/etc/fail2ban/jail.local.bak.$(date +%Y%m%d-%H%M%S)"
    command -v nano >/dev/null 2>&1 || apt-get install -y nano >/dev/null 2>&1
    nano /etc/fail2ban/jail.local
    if confirm "重启 fail2ban 使配置生效？" Y; then
        systemctl restart fail2ban && ok "已重启"
    fi
}

f2b_uninstall() {
    clear; show_banner
    sec "卸载 fail2ban"
    confirm "确认卸载 fail2ban？" N || return
    systemctl stop fail2ban 2>/dev/null
    systemctl disable fail2ban 2>/dev/null
    apt-get purge -y fail2ban
    rm -rf /etc/fail2ban
    ok "fail2ban 已卸载"
}

menu_dd() {
    clear; show_banner
    sec "${RED}DD 重装系统${NC}"
    warn "DD 重装会清空整台 VPS 的所有数据，无法恢复！"
    warn "重装过程中会断开 SSH，结束后用新密码 + 新端口重连"
    echo
    echo -e "  使用 ${BOLD}bin456789/reinstall${NC} 脚本（社区维护，支持系统全）"
    echo "  https://github.com/bin456789/reinstall"
    hr
    echo "  常见系统："
    echo "   1) Debian 13"
    echo "   2) Debian 12"
    echo "   3) Ubuntu 24.04"
    echo "   4) Ubuntu 22.04"
    echo "   5) AlmaLinux 9"
    echo "   6) Rocky Linux 9"
    echo "   7) CentOS 9 Stream"
    echo "   8) Fedora 41"
    echo "   9) Alpine 3.20"
    echo "  10) 其它 (手动输入: 系统名 + 版本)"
    echo "   0) 返回"
    hr
    local c sys
    read -rp "$(echo -e "${CYAN}请选择 [0-10]: ${NC}")" c
    case "$c" in
        1)  sys="debian 13" ;;
        2)  sys="debian 12" ;;
        3)  sys="ubuntu 24.04" ;;
        4)  sys="ubuntu 22.04" ;;
        5)  sys="alma 9" ;;
        6)  sys="rocky 9" ;;
        7)  sys="centos 9" ;;
        8)  sys="fedora 41" ;;
        9)  sys="alpine 3.20" ;;
        10)
            read -rp "  系统名 (如 debian / ubuntu / arch / windows): " os
            read -rp "  版本   (如 13 / 24.04，留空表示无版本): " ver
            [[ -z "$os" ]] && return
            sys="$os $ver"
            ;;
        0|"") return ;;
        *) err "无效"; sleep 1; return ;;
    esac

    # 询问密码（必填，两次核对）
    echo
    echo -e "  ${CYAN}新 root 密码${NC}（必填）"
    local newpw pw2
    while :; do
        read -rp "  密码: " newpw
        if [[ -z "$newpw" ]]; then
            err "密码不能为空"
            continue
        fi
        read -rp "  再输一次: " pw2
        if [[ "$newpw" == "$pw2" ]]; then
            break
        fi
        err "两次输入不一致，请重新输入"
    done

    # 询问 SSH 端口（必填）
    echo
    echo -e "  ${CYAN}新系统的 SSH 端口${NC}（必填，1-65535）"
    local newport
    while :; do
        read -rp "  端口: " newport
        if [[ -z "$newport" ]]; then
            err "端口不能为空"
            continue
        fi
        if ! [[ "$newport" =~ ^[0-9]+$ ]] || (( newport < 1 || newport > 65535 )); then
            err "端口无效（必须是 1-65535 的数字）"
            continue
        fi
        break
    done

    # 最终确认
    echo
    hr
    echo -e "  即将重装为: ${BOLD}${sys}${NC}"
    echo -e "  新 root 密码: ${BOLD}${newpw}${NC}"
    echo -e "  新 SSH 端口:  ${BOLD}${newport}${NC}"
    hr
    confirm "确认开始 DD 重装？" N || { warn "已取消"; return; }

    msg "下载 reinstall 脚本..."
    cd /root 2>/dev/null || cd /tmp
    curl -fsSL -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh \
        || wget -O reinstall.sh https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
    chmod +x reinstall.sh

    msg "执行 DD 重装..."
    warn "完成后 VPS 会自动重启，重启时 SSH 会断开"
    warn "请等待 5-15 分钟，然后用新密码 + 端口 ${newport} 尝试重连"
    sleep 3
    bash reinstall.sh $sys --password "$newpw" --ssh-port "$newport"
    echo
    msg "reinstall 已配置完成，请按提示重启系统开始重装"
    pause
}

# =============================================================================
# 9. 脚本管理
# =============================================================================
menu_script() {
    while :; do
        clear; show_banner
        sec "脚本管理"
        echo "  当前版本: v${SCRIPT_VERSION}  作者: ${SCRIPT_AUTHOR}"
        echo "  脚本路径: ${TB_SCRIPT_PATH}"
        echo "  更新源:   ${SCRIPT_UPDATE_URL}"
        hr
        echo "  1) 更新脚本（强制刷新缓存）"
        echo "  2) 卸载脚本"
        echo "  0) 返回上一页"
        hr
        local c
        read -rp "$(echo -e "${CYAN}请选择 [0-2]: ${NC}")" c
        case "$c" in
            1) update_script; pause ;;
            2) do_uninstall ;;
            0|"") return ;;
            *) err "无效"; sleep 1 ;;
        esac
    done
}

update_script() {
    # 带时间戳，强制绕过 GitHub raw CDN 缓存
    local url="${SCRIPT_UPDATE_URL}?t=$(date +%s)"
    msg "从 ${SCRIPT_UPDATE_URL} 下载新版..."
    local tmp; tmp=$(mktemp)
    if curl -fsSL "$url" -o "$tmp"; then
        if head -n 1 "$tmp" | grep -q '^#!/.*bash'; then
            install -m 755 "$tmp" "$TB_SCRIPT_PATH"
            rm -f "$tmp"
            ok "脚本已更新，请重新执行 tb"
            exit 0
        else
            err "下载内容不是有效脚本"
            rm -f "$tmp"
        fi
    else
        err "下载失败"
        rm -f "$tmp"
    fi
}

do_uninstall() {
    clear; show_banner
    sec "${RED}卸载 toolbox${NC}"
    echo "  仅删除 /usr/local/bin/tb，不动其他任何东西"
    echo "  各软件的卸载请去对应菜单（fail2ban / Docker / BBR 等）"
    echo
    if confirm "确认卸载？" N; then
        rm -f "$TB_SCRIPT_PATH"
        ok "tb 已卸载，再见"
        exit 0
    fi
}

# =============================================================================
# 主菜单
# =============================================================================
main_menu() {
    while :; do
        clear; show_banner
        echo
        echo "  1. 系统"
        echo
        echo "  2. 基础工具"
        echo
        echo "  3. 网络优化 (BBR)"
        echo
        echo "  4. swap 管理"
        echo
        echo "  5. Caddy 反代"
        echo
        echo "  6. Docker 管理"
        echo
        echo "  7. 网络测试"
        echo
        echo "  8. 系统工具 (SSH / DD)"
        echo
        echo "  9. 脚本管理"
        echo
        echo "  0. 退出"
        echo
        hr
        local c
        read -rp "$(echo -e "${CYAN}请输入选项 [0-9]: ${NC}")" c
        case "$c" in
            1) menu_system ;;
            2) menu_basic_tools ;;
            3) menu_network_optim ;;
            4) cfg_swap ;;
            5) menu_caddy_reverse ;;
            6) menu_docker ;;
            7) menu_nettest ;;
            8) menu_systools ;;
            9) menu_script ;;
            0|"") clear; exit 0 ;;
            *) err "无效"; sleep 1 ;;
        esac
    done
}

# =============================================================================
# 首次运行
# =============================================================================
first_install() {
    clear
    local title="Toolbox Script v${SCRIPT_VERSION} By ${SCRIPT_AUTHOR}"
    local w side_eq bytes chars non_ascii_chars ascii_chars visual
    w=$(term_width)
    bytes=$(printf '%s' " ${title} " | wc -c)
    chars=$(printf '%s' " ${title} " | wc -m)
    non_ascii_chars=$(( (bytes - chars) / 2 ))
    ascii_chars=$(( chars - non_ascii_chars ))
    visual=$(( ascii_chars + non_ascii_chars * 2 ))
    side_eq=$(( (w - visual) / 2 ))
    (( side_eq < 3 )) && side_eq=3
    local left right
    left=$(printf "%${side_eq}s" '' | tr ' ' '=')
    right=$(printf "%${side_eq}s" '' | tr ' ' '=')
    echo -e "${GREEN}${left} ${BOLD}${title}${NC}${GREEN} ${right}${NC}"
    echo
    sec "首次运行"
    echo -e "  将把 tb 安装到 ${BOLD}${TB_SCRIPT_PATH}${NC}"
    echo -e "  以后任意目录输入 ${BOLD}tb${NC} 即可呼出菜单。"
    echo
    echo -e "  ${CYAN}本步骤仅复制脚本本身，不会安装其它任何软件${NC}"
    echo
    confirm "确认安装？" Y || { warn "已取消"; exit 0; }
    check_debian
    if [[ "$0" != "$TB_SCRIPT_PATH" ]] && [[ -f "$0" ]]; then
        install -m 755 "$0" "$TB_SCRIPT_PATH"
        ok "已安装到 $TB_SCRIPT_PATH"
    fi
    ok "以后输入 ${BOLD}tb${NC} 即可呼出菜单"
    hr
    pause
}

main() {
    need_root
    # 仅当不在 /usr/local/bin/tb 路径时执行首次安装
    if [[ "$0" != "$TB_SCRIPT_PATH" && ! -x "$TB_SCRIPT_PATH" ]]; then
        first_install
    fi
    main_menu
}

main "$@"
