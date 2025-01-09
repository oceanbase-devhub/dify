#!/usr/bin/env bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

show_help() {
    cat <<EOF
Usage: ./setup-env.sh [options]

Interactively configure OceanBase database connection parameters and update them to the .env file.

Options:
    -h, --help Display this help message and exit
    -t, --test Read the information in .env to test the database connection

Function:
    1. Read the database configuration in the current .env
    2. Interactively obtain the following configuration items:
       - DB_HOST database host address
       - DB_PORT database port
       - DB_USERNAME database user name
       - DB_PASSWORD database password
       - DB_DATABASE OceanBase main database name
       - OCEANBASE_VECTOR_DATABASE OceanBase vector database name
    3. Automatically update .env files
    4. Test database connection

Example:
    ./setup-env.sh runs interactive configuration
    ./setup-env.sh --help displays help information
EOF
}



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

get_user_input() {
    local prompt="$1"
    local default="$2"
    local user_input

    if [ -n "$default" ]; then
        read -p "$(echo -e $BLUE"$prompt [Current: $default]: "$NC)" user_input
        echo "${user_input:-$default}"
    else
        read -p "$(echo -e $BLUE"$prompt: "$NC)" user_input
        echo "$user_input"
    fi
}

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_message "success" "Copied .env.example into .env"
    else
        print_message "error" "ERROR: .env.example not found"
        exit 1
    fi
fi

update_env() {
    local key=$1
    local value=$2
    local file=".env"

    if grep -q "^${key}=" "$file"; then
        if [ "$(uname)" == "Darwin" ]; then
            sed -i '' "s|^${key}=.*|${key}=${value}|" "$file"
        else
            sed -i "s|^${key}=.*|${key}=${value}|" "$file"
        fi
        if [ $? -ne 0 ]; then
            if [ "$(uname)" == "Darwin" ]; then
                sed -i '' "s|^${key}=.*|#${key}=|" "$file" 2&1 >/dev/null
            else
                sed -i "s|^${key}=.*|#${key}=|" "$file" 2&1 >/dev/null
            fi
            echo "${key}=${value}" >>"$file"
        fi
    else
        echo "${key}=${value}" >>"$file"
    fi
}

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

    if ! command -v mysql &>/dev/null; then
        docker run --rm quay.io/oceanbase-devhub/mysql mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D$DB_DATABASE -e "SHOW TABLES"
        if [[ $? != 0 ]]; then
            print_message "error" "$DB_DATABASE Failed to connect to the database\n"
        else
            print_message "success" "$DB_DATABASE Conntected to hte database successfully\n"
        fi

        docker run --rm quay.io/oceanbase-devhub/mysql mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D$OCEANBASE_VECTOR_DATABASE -e "SHOW TABLES"
        if [[ $? != 0 ]]; then
            print_message "error" "$OCEANBASE_VECTOR_DATABASE Failed to connect to the database\n"
        else
            print_message "success" "$OCEANBASE_VECTOR_DATABASE Conntected to hte database successfully\n"
        fi
    else
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D$DB_DATABASE -e "SHOW TABLES"

        if [[ $? != 0 ]]; then
            print_message "error" "$DB_DATABASE Failed to connect to the database\n"
        else
            print_message "success" "$DB_DATABASE Conntected to hte database successfully\n"
        fi

        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USERNAME" -p"$DB_PASSWORD" -D$OCEANBASE_VECTOR_DATABASE -e "SHOW TABLES"

        if [[ $? != 0 ]]; then
            print_message "error" "$OCEANBASE_VECTOR_DATABASE Failed to connect to the database\n"
        else
            print_message "success" "$OCEANBASE_VECTOR_DATABASE Conntected to hte database successfully\n"
        fi
    fi
}

while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
        show_help
        exit 0
        ;;
    -t | --test)
        print_message "info" "Check database connection:\n"
        test_connection "$current_db_host" "$current_db_port" "$current_db_user" "$current_db_password" "$current_db_name" "$current_db_vector_name"
        exit 0
        ;;
    *)
        echo "Unkown flag: $1"
        echo "Use -h or --help to view help message"
        exit 1
        ;;
    esac
done

print_message "info" "Fill in database connection information please:"
DB_HOST=$(get_user_input "Database Host" "$current_db_host")
DB_PORT=$(get_user_input "Database Port" "$current_db_port")
DB_USERNAME=$(get_user_input "Database Username" "$current_db_user")
DB_PASSWORD=$(get_user_input "Database Password" "$current_db_password")
DB_DATABASE=$(get_user_input "Database Name" "$current_db_name")
OCEANBASE_VECTOR_DATABASE=$(get_user_input "Vector Database Name" "$current_db_vector_name")

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

print_message "success" "\nDatabase connection configuration items are written into .env"

print_message "info" "\nCheck database connection:\n"

test_connection "$DB_HOST" "$DB_PORT" "$DB_USERNAME" "$DB_PASSWORD" "$DB_DATABASE" "$OCEANBASE_VECTOR_DATABASE"