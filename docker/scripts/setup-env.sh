#!/usr/bin/env bash

# 设置文本颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    cat <<EOF
用法: ./setup-env.sh [选项]

交互式配置 OceanBase 数据库连接参数并更新到 .env 文件中。

选项:
    -h, --help     显示此帮助信息并退出
    -t, --test     读取 .env 中的信息测试数据库连接

功能:
    1. 读取当前 .env 中的数据库配置
    2. 交互式获取以下配置项:
       - DB_HOST          数据库主机地址
       - DB_PORT          数据库端口
       - DB_USERNAME      数据库用户名
       - DB_PASSWORD      数据库密码
       - DB_DATABASE      OceanBase 主数据库名称
       - OCEANBASE_VECTOR_DATABASE  OceanBase 向量数据库名称
    3. 自动更新 .env 文件
    4. 测试数据库连接

示例:
    ./setup-env.sh          运行交互式配置
    ./setup-env.sh --help   显示帮助信息
EOF
}



# 打印带颜色的提示信息
print_message() {
    local type=$1
    local message=$2
    case $type in
    "info")
        echo -e "${BLUE}$message${NC}"
        ;;
    "success")
        echo -e "${GREEN}$message${NC}"
        ;;
    "error")
        echo -e "${RED}$message${NC}"
        ;;
    *)
        echo -e "${BLUE}$message${NC}"
        ;;
    esac
}

# 从 .env 文件读取值
get_env_value() {
    local key=$1
    local default=$2
    local value=""

    if [ -f ".env" ]; then
        value=$(grep "^${key}=" .env | cut -d '=' -f2-)
    fi

    echo "${value:-$default}"
}

# 获取用户输入
get_user_input() {
    local prompt="$1"
    local default="$2"
    local user_input

    if [ -n "$default" ]; then
        read -p "$(echo -e $BLUE"$prompt [当前值: $default]: "$NC)" user_input
        echo "${user_input:-$default}"
    else
        read -p "$(echo -e $BLUE"$prompt: "$NC)" user_input
        echo "$user_input"
    fi
}

# 检查 .env 文件是否存在
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_message "success" "已从 .env.example 创建新的 .env 文件"
    else
        print_message "error" "错误：未找到 .env.example 文件"
        exit 1
    fi
fi

# 更新 .env 文件
update_env() {
    local key=$1
    local value=$2
    local file=".env"

    # 如果该配置项存在，则更新它
    if grep -q "^${key}=" "$file"; then
        if [ "$(uname)" == "Darwin" ]; then
            sed -i '' "s|^${key}=.*|${key}=${value}|" "$file"
        else
            sed -i "s|^${key}=.*|${key}=${value}|" "$file"
        fi
    else
        # 如果配置项不存在，则添加它
        echo "${key}=${value}" >>"$file"
    fi
}

# 从 .env 获取当前值
current_db_host=$(get_env_value "DB_HOST" "localhost")
current_db_port=$(get_env_value "DB_PORT" "3306")
current_db_user=$(get_env_value "DB_USERNAME" "root")
current_db_password=$(get_env_value "DB_PASSWORD" "")
current_db_name=$(get_env_value "DB_DATABASE" "dify")
current_db_vector_name=$(get_env_value "OCEANBASE_VECTOR_DATABASE" "test")

function test_connection() {
    local DB_HOST=$1
    local DB_PORT=$2
    local DB_USERNAME=$3
    local DB_PASSWORD=$4
    local DB_DATABASE=$5
    local OCEANBASE_VECTOR_DATABASE=$6

    # 如果没有 mysql 命令，使用 docker 运行测试
    if ! command -v mysql &>/dev/null; then
        docker run --rm quay.io/oceanbase-devhub/mysql mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D$DB_DATABASE -e "SHOW TABLES"
        if [[ $? != 0 ]]; then
            print_message "error" "$DB_DATABASE 数据库连接失败!\n"
        else
            print_message "success" "$DB_DATABASE 数据库连接成功~\n"
        fi

        docker run --rm quay.io/oceanbase-devhub/mysql mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D$OCEANBASE_VECTOR_DATABASE -e "SHOW TABLES"
        if [[ $? != 0 ]]; then
            print_message "error" "$OCEANBASE_VECTOR_DATABASE 数据库连接失败!\n"
        else
            print_message "success" "$OCEANBASE_VECTOR_DATABASE 数据库连接成功~\n"
        fi
    else
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D$DB_DATABASE -e "SHOW TABLES"

        if [[ $? != 0 ]]; then
            print_message "error" "$DB_DATABASE 数据库连接失败!\n"
        else
            print_message "success" "$DB_DATABASE 数据库连接成功~\n"
        fi

        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D$OCEANBASE_VECTOR_DATABASE -e "SHOW TABLES"

        if [[ $? != 0 ]]; then
            print_message "error" "$OCEANBASE_VECTOR_DATABASE 数据库连接失败!\n"
        else
            print_message "success" "$OCEANBASE_VECTOR_DATABASE 数据库连接成功~\n"
        fi
    fi
}

# 处理命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
        show_help
        exit 0
        ;;
    -t | --test)
        test_connection "$current_db_host" "$current_db_port" "$current_db_user" "$current_db_password" "$current_db_name" "$current_db_vector_name"
        exit 0
        ;;
    *)
        echo "未知参数: $1"
        echo "使用 -h 或 --help 查看帮助信息"
        exit 1
        ;;
    esac
done

# 获取数据库配置信息
print_message "info" "请输入数据库配置信息："
DB_HOST=$(get_user_input "数据库主机地址" "$current_db_host")
DB_PORT=$(get_user_input "数据库端口" "$current_db_port")
DB_USERNAME=$(get_user_input "数据库用户名" "$current_db_user")
DB_PASSWORD=$(get_user_input "数据库密码" "$current_db_password")
DB_DATABASE=$(get_user_input "数据库名称" "$current_db_name")
OCEANBASE_VECTOR_DATABASE=$(get_user_input "向量数据库名称" "$current_db_vector_name")

# 执行更新
update_env "DB_HOST" "$DB_HOST"
update_env "DB_PORT" "$DB_PORT"
update_env "DB_USERNAME" "$DB_USERNAME"
update_env "DB_PASSWORD" "$DB_PASSWORD"
update_env "DB_DATABASE" "$DB_DATABASE"

update_env "OCEANBASE_VECTOR_HOST" "$DB_HOST"
update_env "OCEANBASE_VECTOR_PORT" "$DB_PORT"
update_env "OCEANBASE_VECTOR_USER" "$DB_USERNAME"
update_env "OCEANBASE_VECTOR_PASSWORD" "$DB_PASSWORD"
update_env "OCEANBASE_VECTOR_DATABASE" "$OCEANBASE_VECTOR_DATABASE"

update_env "SQLALCHEMY_DATABASE_URI_SCHEME" "mysql+pymysql"
update_env "VECTOR_STORE" "oceanbase"

print_message "success" "\n数据库配置已更新到 .env 文件中"

print_message "info" "\n检测数据库连接:\n"

test_connection "$DB_HOST" "$DB_PORT" "$DB_USERNAME" "$DB_PASSWORD" "$DB_DATABASE" "$OCEANBASE_VECTOR_DATABASE"