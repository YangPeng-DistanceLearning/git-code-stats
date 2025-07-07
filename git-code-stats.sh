#!/bin/bash

# ==============================================
# Git 代码统计工具 - 生成代码贡献统计报告
# ==============================================

set -euo pipefail

# 显示帮助信息
function show_help() {
  cat << EOF
Git 代码统计工具 - 生成代码贡献统计报告

用法: $(basename "$0") [选项]

选项:
  -s, --start DATE   起始日期 (默认: 当年开始，格式: YYYY-MM-DD)
  -e, --end DATE     结束日期 (默认: 今天，格式: YYYY-MM-DD)
  -c, --config FILE  配置文件路径 (默认: git-code-config.conf)
  -h, --help         显示此帮助信息

示例:
  $(basename "$0") -s 2025-01-01 -e 2025-05-31 -c my-config.conf

配置文件格式:

[repos]
/path/to/repo1
/path/to/repo2

[authors]
username1 = 显示名称1
username2 = 显示名称2

EOF
  exit 0
}

# 默认值
START_DATE="$(date +%Y)-01-01"
END_DATE="$(date +%Y-%m-%d)"
CONFIG_FILE="git-code-config.conf"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--start)
      START_DATE="$2"
      shift 2
      ;;
    -e|--end)
      END_DATE="$2"
      shift 2
      ;;
    -c|--config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      ;;
    *)
      echo "❌ 未知选项: $1"
      show_help
      ;;
  esac
done

# 定义代码扩展名
CODE_EXTS=("java" "go" "py" "vue" "js" "ts" "jsx" "tsx" "wxml" "wxss" "xml" "yml" "yaml" "pom" "env" "json")

# 定义需要排除的文件
EXCLUDE_PATTERNS=(
  "*.pb.go"           # protobuf 生成的 Go 文件
  "*.pb.gw.go"        # protobuf gateway 生成的文件
  "*.gen.go"          # protobuf 生成的 Go 文件
  "*.pb.java"         # protobuf 生成的 Java 文件
  "*.min.js"          # 压缩的 JS 文件
  "*.min.css"         # 压缩的 CSS 文件
)

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ 配置文件不存在: $CONFIG_FILE"
  exit 1
fi

# 读取配置文件，填充 AUTHOR_MAP 和 REPOS_LIST
declare -A AUTHOR_MAP=()
REPOS_LIST=()

function parse_config() {
  local section=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    # 去掉注释和空白
    line="$(echo "${line%%#*}" | xargs)"
    [[ -z "$line" ]] && continue

    # 检查是否是节标题
    if [[ "$line" =~ ^\[(.*)\]$ ]]; then
      section="${BASH_REMATCH[1]}"
      continue
    fi

    # 处理内容
    case "$section" in
      authors)
        if [[ "$line" =~ ^([^=]+)=(.+)$ ]]; then
          local key="$(echo "${BASH_REMATCH[1]}" | xargs | tr '[:upper:]' '[:lower:]')"
          local val="$(echo "${BASH_REMATCH[2]}" | xargs)"
          AUTHOR_MAP["$key"]="$val"
        fi
        ;;
      repos)
        REPOS_LIST+=("$line")
        ;;
    esac
  done < "$CONFIG_FILE"
}

parse_config

if [[ ${#REPOS_LIST[@]} -eq 0 ]]; then
  echo "❌ 配置文件中没有配置 repos 仓库列表，退出"
  exit 1
fi

echo "📝 代码提交月报"
echo "📅 时间范围: $START_DATE 至 $END_DATE "
echo "📁 仓库列表: "
for repo in "${REPOS_LIST[@]}"; do
  echo "    - $repo"
done
echo

# 将 AUTHOR_MAP 序列化为字符串传给 awk
author_map_str=""
for k in "${!AUTHOR_MAP[@]}"; do
  key="$(echo "$k" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"     # trim
  val="$(echo "${AUTHOR_MAP[$k]}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" # trim
  author_map_str+="${key}=${val};"
done

ext_regex="\\\\.("$(IFS="|"; echo "${CODE_EXTS[*]}")")\$"

# 将排除的文件序列化为字符串传给 awk
exclude_patterns_str=""
for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  exclude_patterns_str+="${pattern};"
done

# 多仓库统计，合并结果
{
  for repo_path in "${REPOS_LIST[@]}"; do
    echo "🔍 正在分析仓库: $repo_path"
    if [[ ! -d "$repo_path/.git" ]]; then
      echo "⚠️ 跳过：$repo_path 不是有效的 Git 仓库"
      continue
    fi
    (
      cd "$repo_path"
      git log --since="$START_DATE" --until="$END_DATE" --pretty="%ad%x09%an" --date=format:"%Y-%m" --numstat
    )
  done
} | awk -v exts="$ext_regex" -v am="$author_map_str" -v excludes="$exclude_patterns_str" '
  # 检查文件是否应该被排除
  function should_exclude(filepath) {
    # 将排除模式字符串分割成数组
    split(excludes, patterns, ";")
    for (i in patterns) {
      if (patterns[i] == "") continue
      pattern = patterns[i]
      
      # 处理目录模式（以/结尾）
      if (match(pattern, /\/$/)) {
        if (index(filepath, pattern) > 0) return 1
      }
      # 处理通配符模式
      else if (index(pattern, "*") > 0) {
        # 将通配符转换为正则表达式
        regex_pattern = pattern
        gsub(/\./, "\\.", regex_pattern)  # 转义点号
        gsub(/\*/, ".*", regex_pattern)   # 转换星号为.*
        if (filepath ~ regex_pattern) return 1
      }
      # 处理精确匹配
      else {
        if (filepath == pattern) return 1
      }
    }
    return 0
  }

  # 计算字符串显示宽度（考虑中文字符占两个位置）
  function strwidth(s) {
    w = 0
    for (i = 1; i <= length(s); i++) {
      c = substr(s, i, 1)
      if (c ~ /[^\x00-\x7F]/) {
        w += 2
      } else {
        w += 1
      }
    }
    return w
  }

  # 填充字符串到指定宽度
  function pad(s, target) {
    w = strwidth(s)
    padlen = target - w
    result = s
    if (padlen > 0) {
      for (i = 1; i <= padlen; i++) result = result " "
    }
    return result
  }

  # 格式化净变更数，添加颜色高亮
  function format_net_change(net) {
    if (net > 0) {
      return sprintf("%s%+d%s", GREEN, net, RESET)
    } else if (net < 0) {
      return sprintf("%s%+d%s", RED, net, RESET)
    } else {
      return sprintf("%+d", net)
    }
  }
  
  # 打印表头
  function print_header() {
    print "📊 统计结果"
    print_separator()
    print "   👤 作者        ➕ 新增    ➖ 删除    🔁 净变更  📌 贡献%"
    print_separator()
  }

  # 打印月份标题
  function print_month_header(month) {
    print "🟢 月份: " month
  }

  # 打印分隔线
  function print_separator() {
    print "────────────────────────────────────────────────────────────"
  }

  # 打印作者统计信息
  function print_author_stats(author, a_add, a_del, net, rate) {
    # 使用 format_net_change 函数格式化净变更，添加颜色
    net_str = format_net_change(net)
    
    # 计算净变更数的实际数字长度（不含颜色代码）
    net_len = length(sprintf("%+d", net))
    # 根据净变更数长度动态计算间距
    padding = 8 - net_len  # 保留8个位置给净变更数
    spaces = ""
    for (i = 0; i < padding; i++) spaces = spaces " "
    
    printf "   👤 %s", pad(author, 10)
    printf "  ➕ %-6d  ➖ %-6d  🔁 %s%s", a_add, a_del, net_str, spaces
    printf "📌 %4.1f%%\n", rate
  }

  # 打印总计信息
  function print_summary(t_add, t_del) {
    net = t_add - t_del
    net_str = format_net_change(net)
    printf "🔚 总计: 新增 %d 行, 删除 %d 行, 净变更 %s\n", 
           t_add, t_del, net_str
  }

  BEGIN {
    FS = "\t"
    RED = "\033[31m"
    GREEN = "\033[32m"
    RESET = "\033[0m"

    # 解析作者映射
    split(am, pairs, ";")
    for (i in pairs) {
      if (pairs[i] == "") continue
      split(pairs[i], kv, "=")
      author_map[kv[1]] = kv[2]
    }
  }

  /^([0-9]{4}-[0-9]{2})\t/ {
    curr_month = $1
    curr_author = $2
    next
  }

  $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $3 ~ exts {
    # 检查文件是否应该被排除
    if (should_exclude($3)) {
      next
    }

    author_key = tolower(curr_author)
    author_name = (author_key in author_map) ? author_map[author_key] : curr_author

    key = curr_month "|" author_name
    add[key] += $1
    del[key] += $2
    month_total_add[curr_month] += $1
    authors[curr_month][author_name] = 1
    total_add += $1
    total_del += $2
  }

  END {
    PROCINFO["sorted_in"] = "@ind_str_asc"
    
    # 输出表头
    print_header()
    
    for (month in month_total_add) {
      print_month_header(month)
      for (key in add) {
        split(key, parts, "|")
        m = parts[1]
        author = parts[2]
        if (m != month) continue

        a_add = add[key]
        a_del = del[key]
        net = a_add - a_del
        rate = (month_total_add[month] > 0) ? a_add / month_total_add[month] * 100 : 0

        print_author_stats(author, a_add, a_del, net, rate)
      }
      print_separator()
    }

    print_summary(total_add, total_del)
  }
'

echo "✅ 统计完成"
