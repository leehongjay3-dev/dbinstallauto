#!/bin/bash

# 颜色定义用于输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
SCRIPT_SUCCESS=true
ERROR_MESSAGES=()

# 日志函数
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ERROR_MESSAGES+=("$1")
    SCRIPT_SUCCESS=false
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# 检查命令执行状态的函数
check_status() {
    local cmd_status=$?
    local cmd_desc="$1"
    local exit_on_failure="${2:-false}"
    
    if [ $cmd_status -eq 0 ]; then
        log_success "$cmd_desc"
        return 0
    else
        log_error "$cmd_desc (错误码: $cmd_status)"
        
        if [ "$exit_on_failure" = "true" ]; then
            log_error "致命错误，脚本中止执行！"
            exit 1
        fi
        
        return $cmd_status
    fi
}

# 执行命令并记录日志
execute_command() {
    local cmd="$1"
    local cmd_desc="$2"
    local exit_on_failure="${3:-false}"
    
    log_info "执行: $cmd_desc"
    
    # 执行命令并捕获输出
    if eval "$cmd" 2>&1; then
        log_success "$cmd_desc 完成"
        return 0
    else
        local cmd_status=$?
        log_error "$cmd_desc 失败 (错误码: $cmd_status)"
        
        if [ "$exit_on_failure" = "true" ]; then
            log_error "致命错误，脚本中止执行！"
            exit 1
        fi
        
        return $cmd_status
    fi
}

# 第一个函数: 安装RPM包
fun_rpm_install() {
    log_info "===== 开始执行: fun_rpm_install - 安装必要的RPM包 ====="
    
    # 清理yum缓存
    execute_command "yum clean all" "清理yum缓存"
    
    # 更新系统
    execute_command "yum update -y" "更新系统软件包"
    
    # 安装必要的软件包  glibc-devel.i686 20260212 for oem
    log_info "安装必要的软件包列表..."  
    execute_command "yum -y install bc xdpyinfo binutils elfutils-libelf elfutils-libelf-devel fontconfig-devel glibc glibc-devel ksh libaio libaio-devel libXrender libX11 libXau libXi libXtst libgcc libnsl librdmacm libstdc++ libstdc++-devel libxcb libibverbs make policycoreutils policycoreutils-python-utils smartmontools sysstat glibc-devel.i686" "安装Oracle依赖包"
    
    # 验证关键包是否安装成功
    log_info "验证关键包是否安装成功..."
    local critical_packages=("libaio" "libaio-devel" "ksh" "bc" "glibc-devel")
    local missing_packages=()
    
    for pkg in "${critical_packages[@]}"; do
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            missing_packages+=("$pkg")
            log_warning "关键包 $pkg 未安装成功"
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_warning "以下关键包未安装成功: ${missing_packages[*]}"
        log_warning "这可能影响Oracle的正常安装，建议手动安装这些包"
    else
        log_success "所有关键包都已成功安装"
    fi
    
    log_info "===== fun_rpm_install 执行完成 ====="
    return 0
}

# 第二个函数: 创建用户和组
fun_user_install() {
    log_info "===== 开始执行: fun_user_install - 创建用户和组 ====="
    
    # 检查是否以root运行
    if [ "$(id -u)" != "0" ]; then
        log_error "此函数需要以root权限运行"
        return 1
    fi
    
    # 定义组和用户信息
    local groups=(
        "1010:oinstall"
        "1011:asmadmin"
        "1012:asmdba"
        "1013:asmoper"
        "1014:dba"
        "1015:oper"
        "1016:bkupdba"
        "1017:dgdba"
        "1018:racdba"
        "1019:kmdba"
    )
    
    # 创建组
    log_info "创建系统组..."
    for group_info in "${groups[@]}"; do
        local gid="${group_info%%:*}"
        local group_name="${group_info##*:}"
        
        if getent group "$group_name" >/dev/null; then
            log_warning "组 $group_name 已存在，跳过创建"
        else
            execute_command "groupadd -g $gid $group_name" "创建组 $group_name (GID: $gid)"
        fi
    done
    
    # 创建grid用户
    if id "grid" >/dev/null 2>&1; then
        log_warning "用户 grid 已存在，跳过创建"
    else
        execute_command "/usr/sbin/useradd -u 2000 -g oinstall -G asmadmin,asmdba,asmoper,dba,racdba grid" "创建用户 grid"
        execute_command "echo 'grid:!QAZ2wsx#EDC4rfv' | chpasswd" "设置grid用户密码"
    fi
    
    # 创建oracle用户
    if id "oracle" >/dev/null 2>&1; then
        log_warning "用户 oracle 已存在，跳过创建"
    else
        execute_command "/usr/sbin/useradd -u 2100 -g oinstall -G dba,asmdba,asmadmin,oper,bkupdba,dgdba,racdba,kmdba oracle" "创建用户 oracle"
        execute_command "echo 'oracle:!QAZ2wsx#EDC4rfv' | chpasswd" "设置oracle用户密码"
    fi
    
    # 验证用户创建
    log_info "验证用户创建..."
    if id "grid" >/dev/null 2>&1 && id "oracle" >/dev/null 2>&1; then
        log_success "用户 grid 和 oracle 创建成功"
        
        # 显示用户信息
        log_info "用户 grid 信息:"
        id grid
        log_info "用户 oracle 信息:"
        id oracle
    else
        log_error "用户创建验证失败"
    fi
    
    log_info "===== fun_user_install 执行完成 ====="
    return 0
}

# 第三个函数: 创建目录和设置权限
fun_file_install() {
    log_info "===== 开始执行: fun_file_install - 创建目录和设置权限 ====="
    
    # 定义目录列表
    local directories=(
        "/app/oraInventory"
        "/app/grid"
        "/app/oracle"
		"/app/oracle/product/26/db_1"
		"/app/oracle/product/11/db_1"
        "/app/oracle/product/19/db_1"
    )
    
    # 创建目录
    log_info "创建目录结构..."
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            log_warning "目录 $dir 已存在，跳过创建"
        else
            execute_command "mkdir -p '$dir'" "创建目录 $dir"
        fi
    done
    
    # 设置所有权[安装grid的时候需要再次验证 20260212]
    log_info "设置目录所有权..."
    
    # 检查用户是否存在
    if ! id "grid" >/dev/null 2>&1; then
        log_warning "用户 grid 不存在，跳过设置grid用户相关的目录所有权"
    else
        execute_command "chown -R grid:oinstall /app/oraInventory" "设置 /app/oraInventory 所有者为 grid:oinstall"
        execute_command "chown -R grid:oinstall /app/grid" "设置 /app/grid 所有者为 grid:oinstall"
    fi
    
    if ! id "oracle" >/dev/null 2>&1; then
        log_warning "用户 oracle 不存在，跳过设置oracle用户相关的目录所有权"
    else
        execute_command "chown -R oracle:oinstall /app" "设置 /app/oracle 所有者为 oracle:oinstall"
		#2026 0211 权限部分
        #execute_command "chown oracle:oinstall /app/oracle/product/19/db_1" "设置 /app/oracle/product/19/db_1 所有者为 oracle:oinstall"
    fi
    
    # 设置权限
    log_info "设置目录权限..."
    execute_command "chmod -R 775 /app" "设置 /app 目录权限为 775"
    execute_command "chmod 1777 /tmp" "设置 /tmp 目录权限为 1777"
    
    # 添加用户到vboxsf组（仅在VirtualBox环境中需要）
    if getent group vboxsf >/dev/null; then
        log_info "检测到vboxsf组，添加用户到vboxsf组..."
        
        if id "oracle" >/dev/null 2>&1; then
            execute_command "usermod -aG vboxsf oracle" "添加 oracle 用户到 vboxsf 组"
        fi
        
        if id "grid" >/dev/null 2>&1; then
            execute_command "usermod -aG vboxsf grid" "添加 grid 用户到 vboxsf 组"
        fi
    else
        log_warning "vboxsf组不存在（可能不在VirtualBox环境中），跳过此步骤"
    fi
    
    # 验证目录权限
    log_info "验证目录权限..."
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            log_info "目录 $dir 权限: $(stat -c '%A %U:%G' "$dir")"
        fi
    done
    
    log_info "===== fun_file_install 执行完成 ====="
    return 0
}

# 显示执行摘要
show_summary() {
    log_info "===== 脚本执行摘要 ====="
    
    if [ "$SCRIPT_SUCCESS" = true ]; then
        log_success "所有函数执行完成，没有致命错误"
    else
        log_warning "脚本执行完成，但有错误发生"
        
        echo -e "\n${YELLOW}错误摘要:${NC}"
        for error_msg in "${ERROR_MESSAGES[@]}"; do
            echo -e "${RED}  • $error_msg${NC}"
        done
        echo
    fi
    
    # 显示关键检查点
    log_info "关键检查点状态:"
    
    # 检查用户
    if id "grid" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ 用户 grid 存在${NC}"
    else
        echo -e "${RED}  ✗ 用户 grid 不存在${NC}"
    fi
    
    if id "oracle" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓ 用户 oracle 存在${NC}"
    else
        echo -e "${RED}  ✗ 用户 oracle 不存在${NC}"
    fi
    
    # 检查关键目录
    local critical_dirs=("/app/oraInventory" "/app/grid" "/app/oracle")
    for dir in "${critical_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "${GREEN}  ✓ 目录 $dir 存在${NC}"
        else
            echo -e "${RED}  ✗ 目录 $dir 不存在${NC}"
        fi
    done
    
    log_info "===== 脚本执行结束 ====="
}

# 主执行流程
main() {
    log_info "===== Oracle安装自动化脚本开始执行 ====="
    log_info "脚本将尝试执行所有步骤，即使某些步骤失败也会继续"
    echo
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 执行第一个函数
    log_info "执行第一步: 安装RPM包"
    if fun_rpm_install; then
        log_success "第一步执行完成"
    else
        log_warning "第一步执行遇到问题，继续执行后续步骤..."
    fi
    echo
    
    # 执行第二个函数
    log_info "执行第二步: 创建用户和组"
    if fun_user_install; then
        log_success "第二步执行完成"
    else
        log_warning "第二步执行遇到问题，继续执行后续步骤..."
    fi
    echo
    
    # 执行第三个函数
    log_info "执行第三步: 创建目录和设置权限"
    if fun_file_install; then
        log_success "第三步执行完成"
    else
        log_warning "第三步执行遇到问题"
    fi
    echo
    
    # 计算执行时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 显示摘要
    show_summary
    
    log_info "总执行时间: ${duration}秒"
    
    # 根据执行结果返回适当的退出码
    if [ "$SCRIPT_SUCCESS" = true ]; then
        exit 0
    else
        exit 1
    fi
}

# 脚本参数处理
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Oracle安装自动化脚本"
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --help, -h    显示此帮助信息"
    echo "  --rpm-only    仅执行RPM安装步骤"
    echo "  --user-only   仅执行用户创建步骤"
    echo "  --file-only   仅执行目录创建步骤"
    echo "  --summary     仅显示系统状态摘要"
    exit 0
fi

# 根据参数执行不同的功能
case "$1" in
    "--rpm-only")
        fun_rpm_install
        ;;
    "--user-only")
        fun_user_install
        ;;
    "--file-only")
        fun_file_install
        ;;
    "--summary")
        show_summary
        ;;
    *)
        # 默认执行全部
        main
        ;;
esac
