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
INSTALL_LOG_FILE="/tmp/oracle_install_$(date +%Y%m%d_%H%M%S).log"
INSTALL_SUCCESS=false

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

# 检查Oracle安装前置条件
check_prerequisites() {
    log_info "===== 开始检查Oracle安装前置条件 ====="
    
    # 检查Oracle用户是否存在
    if ! id "oracle" >/dev/null 2>&1; then
        log_error "用户 oracle 不存在，请先创建用户"
        return 1
    fi
    
    # 检查ORACLE_HOME目录是否存在
    if [ ! -d "/app/oracle/product/26/db_1" ]; then
        log_error "ORACLE_HOME目录不存在: /app/oracle/product/26/db_1"
        return 1
    fi
    
    # 检查响应文件是否存在
    if [ ! -f "/home/oracle/installdb.rsp" ]; then
        log_warning "响应文件不存在: /home/oracle/installdb.rsp"
        log_info "正在检查默认位置..."
        
        # 检查可能的响应文件位置
        local possible_locations=(
            "/app/oracle/installdb.rsp"
            "/tmp/installdb.rsp"
            "/home/oracle/db_install.rsp"
        )
        
        local found_response_file=""
        for location in "${possible_locations[@]}"; do
            if [ -f "$location" ]; then
                found_response_file="$location"
                log_info "找到响应文件: $location"
                break
            fi
        done
        
        if [ -z "$found_response_file" ]; then
            log_error "未找到响应文件，请确保响应文件存在"
            return 1
        fi
    else
        log_success "响应文件存在: /home/oracle/installdb.rsp"
    fi
    
    # 检查runInstaller是否存在
    if [ ! -f "/app/oracle/product/26/db_1/runInstaller" ]; then
        log_error "runInstaller不存在: /app/oracle/product/26/db_1/runInstaller"
        return 1
    fi
    
    # 检查磁盘空间
    local free_space=$(df -h /app | awk 'NR==2 {print $4}')
    log_info "安装目录可用空间: $free_space"
    
    # 检查内存
    local total_memory=$(free -g | awk '/^Mem:/ {print $2}')
    if [ "$total_memory" -lt 8 ]; then
        log_warning "内存可能不足 (当前: ${total_memory}GB, 推荐: 8GB)"
    else
        log_success "内存充足: ${total_memory}GB"
    fi
    
    # 检查Swap空间
    local swap_space=$(free -g | awk '/^Swap:/ {print $2}')
    log_info "Swap空间: ${swap_space}GB"
    
    log_success "前置条件检查完成"
    return 0
}

# 安装Oracle数据库
install_oracle_db() {
    log_info "===== 开始安装Oracle数据库 ====="
    
    # 切换到Oracle用户
    if [ "$(whoami)" != "oracle" ]; then
        log_info "当前用户为 $(whoami)，切换到 oracle 用户执行安装"
        # 这里可以根据需要决定是否切换到oracle用户
        # 在实际脚本中，可能需要使用su或sudo来切换用户
    fi
    
    # 切换到ORACLE_HOME目录
    cd "/app/oracle/product/26/db_1" || {
        log_error "无法切换到目录: /app/oracle/product/26/db_1"
        return 1
    }
    
    # 获取响应文件路径
    local response_file="/home/oracle/installdb.rsp"
    if [ ! -f "$response_file" ]; then
        # 尝试其他可能的位置
        if [ -f "/app/oracle/installdb.rsp" ]; then
            response_file="/app/oracle/installdb.rsp"
        elif [ -f "/tmp/installdb.rsp" ]; then
            response_file="/tmp/installdb.rsp"
        else
            log_error "未找到响应文件"
            return 1
        fi
    fi
    
    log_info "使用响应文件: $response_file"
    log_info "开始执行Oracle数据库安装..."
    
    # 创建安装日志目录
    mkdir -p "/tmp/oracle_install_logs"
    
    # 执行安装命令并捕获输出
    log_info "执行命令: ./runInstaller -silent -responseFile $response_file -ignorePrereqFailure -waitForCompletion"
    
    # 将安装输出同时显示在终端和保存到文件
    {
        echo "开始Oracle数据库安装..."
        echo "时间: $(date)"
        echo "========================================"
        
        # 执行安装命令
        ./runInstaller -silent -responseFile "$response_file" -ignorePrereqFailure -waitForCompletion 2>&1
        
        local install_status=$?
        echo "========================================"
        echo "安装命令退出状态: $install_status"
        echo "时间: $(date)"
    } | tee "$INSTALL_LOG_FILE"
    
    # 检查安装输出中是否包含"Execute"关键字
    if grep -q "Execute" "$INSTALL_LOG_FILE"; then
        INSTALL_SUCCESS=true
        log_success "检测到'Execute'关键字，数据库安装成功！"
        
        # 提取需要执行的root脚本
        log_info "提取需要执行的root脚本..."
        grep -A2 "Execute.*root.sh" "$INSTALL_LOG_FILE" || true
        
        # 显示具体的脚本路径
        echo ""
        log_info "请执行以下root脚本完成安装："
        
        # 提取orainstRoot.sh路径
        local orainst_script=$(grep -o "/app/oraInventory/orainstRoot.sh" "$INSTALL_LOG_FILE" | head -1)
        if [ -n "$orainst_script" ]; then
            log_info "1. $orainst_script"
        fi
        
        # 提取root.sh路径
        local root_script=$(grep -o "/app/oracle/product/26/db_1/root.sh" "$INSTALL_LOG_FILE" | head -1)
        if [ -n "$root_script" ]; then
            log_info "2. $root_script"
        fi
        
        # 如果未在输出中找到脚本路径，使用默认路径
        if [ -z "$orainst_script" ] && [ -f "/app/oraInventory/orainstRoot.sh" ]; then
            log_info "1. /app/oraInventory/orainstRoot.sh"
        fi
        
        if [ -z "$root_script" ] && [ -f "/app/oracle/product/26/db_1/root.sh" ]; then
            log_info "2. /app/oracle/product/26/db_1/root.sh"
        fi
        
    else
        INSTALL_SUCCESS=false
        log_error "未检测到'Execute'关键字，数据库安装可能失败！"
        
        # 检查是否有其他成功标志
        if grep -q "Successfully Setup Software" "$INSTALL_LOG_FILE"; then
            log_warning "检测到'Successfully Setup Software'，但未找到'Execute'关键字"
            log_warning "请检查安装日志确认是否成功：$INSTALL_LOG_FILE"
        else
            log_error "未找到安装成功标志"
        fi
    fi
    
    # 检查安装命令的退出状态
    local install_status=$(grep "安装命令退出状态:" "$INSTALL_LOG_FILE" | tail -1 | awk '{print $NF}')
    if [ -n "$install_status" ] && [ "$install_status" -eq 0 ]; then
        log_success "安装程序退出状态: 0 (成功)"
    elif [ -n "$install_status" ]; then
        log_error "安装程序退出状态: $install_status (失败)"
        INSTALL_SUCCESS=false
    fi
    
    log_info "安装日志已保存到: $INSTALL_LOG_FILE"
    
    # 复制日志到Oracle库存目录
    if [ -d "/app/oraInventory/logs" ]; then
        cp "$INSTALL_LOG_FILE" "/app/oraInventory/logs/" 2>/dev/null && \
        log_info "安装日志已备份到: /app/oraInventory/logs/"
    fi
    
    log_info "===== Oracle数据库安装完成 ====="
    return 0
}

# 执行root脚本
execute_root_scripts() {
    log_info "===== 开始执行root脚本 ====="
    
    # 检查当前用户是否为root
    if [ "$(id -u)" != "0" ]; then
        log_warning "当前用户不是root，无法执行root脚本"
        log_info "请以root用户执行以下脚本："
        
        if [ -f "/app/oraInventory/orainstRoot.sh" ]; then
            echo "1. /app/oraInventory/orainstRoot.sh"
        fi
        
        if [ -f "/app/oracle/product/26/db_1/root.sh" ]; then
            echo "2. /app/oracle/product/26/db_1/root.sh"
        fi
        
        return 0
    fi
    
    # 执行orainstRoot.sh
    if [ -f "/app/oraInventory/orainstRoot.sh" ]; then
        log_info "执行: /app/oraInventory/orainstRoot.sh"
        if /app/oraInventory/orainstRoot.sh; then
            log_success "orainstRoot.sh 执行成功"
        else
            log_error "orainstRoot.sh 执行失败"
            return 1
        fi
    else
        log_warning "未找到 /app/oraInventory/orainstRoot.sh"
    fi
    
    # 执行root.sh
    if [ -f "/app/oracle/product/26/db_1/root.sh" ]; then
        log_info "执行: /app/oracle/product/26/db_1/root.sh"
        if /app/oracle/product/26/db_1/root.sh; then
            log_success "root.sh 执行成功"
        else
            log_error "root.sh 执行失败"
            return 1
        fi
    else
        log_warning "未找到 /app/oracle/product/26/db_1/root.sh"
    fi
    
    log_success "root脚本执行完成"
    return 0
}

# 验证安装结果
verify_installation() {
    log_info "===== 开始验证Oracle数据库安装 ====="
    
    local verification_passed=true
    
    # 检查Oracle进程
    log_info "检查Oracle进程..."
    if pgrep -f ora_pmon >/dev/null 2>&1; then
        log_success "Oracle PMON进程正在运行"
    else
        log_warning "Oracle PMON进程未运行（数据库可能未启动）"
        verification_passed=false
    fi
    
    # 检查监听器
    log_info "检查监听器状态..."
    if su - oracle -c "lsnrctl status" >/dev/null 2>&1; then
        log_success "Oracle监听器正在运行"
    else
        log_warning "Oracle监听器未运行"
        verification_passed=false
    fi
    
    # 检查SQL*Plus连接
    log_info "检查数据库连接..."
    if su - oracle -c "echo 'select * from dual;' | sqlplus -s / as sysdba" >/dev/null 2>&1; then
        log_success "可以连接到数据库"
    else
        log_warning "无法连接到数据库"
        verification_passed=false
    fi
    
    # 检查环境变量
    log_info "检查Oracle环境变量..."
    if su - oracle -c 'echo $ORACLE_HOME' | grep -q "/app/oracle/product/26/db_1"; then
        log_success "ORACLE_HOME设置正确"
    else
        log_warning "ORACLE_HOME可能未正确设置"
        verification_passed=false
    fi
    
    if su - oracle -c 'echo $ORACLE_SID' | grep -q ".*"; then
        log_success "ORACLE_SID已设置"
    else
        log_warning "ORACLE_SID未设置"
    fi
    
    if [ "$verification_passed" = true ]; then
        log_success "Oracle数据库验证通过"
    else
        log_warning "Oracle数据库验证未通过，请检查安装日志"
    fi
    
    return 0
}

# 显示执行摘要
show_summary() {
    log_info "===== 脚本执行摘要 ====="
    
    if [ "$INSTALL_SUCCESS" = true ]; then
        log_success "Oracle数据库安装成功！检测到'Execute'关键字"
        
        echo -e "\n${GREEN}安装成功摘要:${NC}"
        echo -e "${GREEN}  ✓ 检测到'Execute'关键字${NC}"
        
        # 检查root脚本是否存在
        if [ -f "/app/oraInventory/orainstRoot.sh" ]; then
            echo -e "${GREEN}  ✓ orainstRoot.sh 已生成${NC}"
        else
            echo -e "${YELLOW}  ⚠  orainstRoot.sh 未找到${NC}"
        fi
        
        if [ -f "/app/oracle/product/26/db_1/root.sh" ]; then
            echo -e "${GREEN}  ✓ root.sh 已生成${NC}"
        else
            echo -e "${YELLOW}  ⚠  root.sh 未找到${NC}"
        fi
        
    else
        log_error "Oracle数据库安装失败！未检测到'Execute'关键字"
        
        echo -e "\n${RED}安装失败摘要:${NC}"
        echo -e "${RED}  ✗ 未检测到'Execute'关键字${NC}"
        
        # 提供故障排除建议
        echo -e "\n${YELLOW}故障排除建议:${NC}"
        echo -e "${YELLOW}  1. 检查响应文件配置${NC}"
        echo -e "${YELLOW}  2. 检查磁盘空间和权限${NC}"
        echo -e "${YELLOW}  3. 查看详细安装日志: $INSTALL_LOG_FILE${NC}"
        echo -e "${YELLOW}  4. 检查Oracle安装文档${NC}"
    fi
    
    echo -e "\n${BLUE}安装日志位置:${NC}"
    echo -e "  ${BLUE}• 主要安装日志: $INSTALL_LOG_FILE${NC}"
    
    if [ -d "/app/oraInventory/logs" ]; then
        local latest_log=$(ls -t /app/oraInventory/logs/InstallActions* 2>/dev/null | head -1)
        if [ -n "$latest_log" ]; then
            echo -e "  ${BLUE}• Oracle安装日志: $latest_log${NC}"
        fi
    fi
    
    if [ ${#ERROR_MESSAGES[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}错误摘要:${NC}"
        for error_msg in "${ERROR_MESSAGES[@]}"; do
            echo -e "${RED}  • $error_msg${NC}"
        done
    fi
    
    log_info "===== 脚本执行结束 ====="
}

# 显示安装状态
show_install_status() {
    log_info "===== Oracle数据库安装状态 ====="
    
    if [ "$INSTALL_SUCCESS" = true ]; then
        echo -e "${GREEN}安装状态: 成功${NC}"
        echo -e "${GREEN}关键标志: 检测到'Execute'关键字${NC}"
    else
        echo -e "${RED}安装状态: 失败${NC}"
        echo -e "${RED}关键标志: 未检测到'Execute'关键字${NC}"
    fi
    
    # 显示关键文件状态
    echo -e "\n${BLUE}关键文件状态:${NC}"
    
    local files_to_check=(
        "/app/oracle/product/26/db_1/runInstaller"
        "/home/oracle/installdb.rsp"
        "/app/oraInventory/orainstRoot.sh"
        "/app/oracle/product/26/db_1/root.sh"
    )
    
    for file in "${files_to_check[@]}"; do
        if [ -f "$file" ]; then
            echo -e "${GREEN}  ✓ $file${NC}"
        else
            echo -e "${RED}  ✗ $file${NC}"
        fi
    done
    
    # 显示安装日志位置
    if [ -f "$INSTALL_LOG_FILE" ]; then
        echo -e "\n${BLUE}安装日志:${NC}"
        echo -e "${BLUE}  $INSTALL_LOG_FILE${NC}"
        
        # 显示日志中是否包含Execute
        if grep -q "Execute" "$INSTALL_LOG_FILE"; then
            echo -e "${GREEN}  日志中包含'Execute'关键字${NC}"
        else
            echo -e "${RED}  日志中未包含'Execute'关键字${NC}"
        fi
    fi
}

# 主执行流程
main() {
    log_info "===== Oracle数据库安装脚本开始执行 ====="
    log_info "脚本将检查'Execute'关键字来判断安装是否成功"
    echo
    
    # 记录开始时间
    local start_time=$(date +%s)
    
    # 步骤1: 检查前置条件
    log_info "执行第一步: 检查安装前置条件"
    if check_prerequisites; then
        log_success "第一步执行完成"
    else
        log_warning "第一步执行遇到问题，继续执行后续步骤..."
    fi
    echo
    
    # 步骤2: 安装Oracle数据库
    log_info "执行第二步: 安装Oracle数据库"
    if install_oracle_db; then
        log_success "第二步执行完成"
    else
        log_warning "第二步执行遇到问题"
    fi
    echo
    
    # 步骤3: 如果安装成功，执行root脚本
    if [ "$INSTALL_SUCCESS" = true ]; then
        log_info "执行第三步: 执行root脚本"
        if execute_root_scripts; then
            log_success "第三步执行完成"
        else
            log_warning "第三步执行遇到问题"
        fi
        echo
        
        # 步骤4: 验证安装
        log_info "执行第四步: 验证安装结果"
        if verify_installation; then
            log_success "第四步执行完成"
        else
            log_warning "第四步执行遇到问题"
        fi
    else
        log_warning "由于安装未成功，跳过root脚本执行和验证步骤"
    fi
    echo
    
    # 计算执行时间
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # 显示摘要
    show_summary
    
    log_info "总执行时间: ${duration}秒"
    
    # 根据执行结果返回适当的退出码
    if [ "$INSTALL_SUCCESS" = true ]; then
        exit 0
    else
        exit 1
    fi
}

# 脚本参数处理
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Oracle数据库安装脚本"
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  --help, -h        显示此帮助信息"
    echo "  --check-only      仅检查前置条件"
    echo "  --install-only    仅执行数据库安装"
    echo "  --root-only       仅执行root脚本"
    echo "  --verify-only     仅验证安装结果"
    echo "  --status          显示安装状态"
    echo "  --show-log        显示安装日志"
    echo "  --force-install   强制重新安装（不检查前置条件）"
    exit 0
fi

# 根据参数执行不同的功能
case "$1" in
    "--check-only")
        check_prerequisites
        ;;
    "--install-only")
        install_oracle_db
        ;;
    "--root-only")
        execute_root_scripts
        ;;
    "--verify-only")
        verify_installation
        ;;
    "--status")
        show_install_status
        ;;
    "--show-log")
        if [ -f "$INSTALL_LOG_FILE" ]; then
            cat "$INSTALL_LOG_FILE"
        else
            echo "安装日志不存在: $INSTALL_LOG_FILE"
            echo "请先执行安装"
            exit 1
        fi
        ;;
    "--force-install")
        log_warning "强制安装模式，跳过前置条件检查"
        install_oracle_db
        ;;
    *)
        # 默认执行全部
        main
        ;;
esac