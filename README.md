# Git 代码贡献统计工具

[![Bash](https://img.shields.io/badge/Language-Bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

一个用于生成 Git 仓库代码贡献统计报告的命令行工具，支持多仓库合并统计和自定义作者名称显示。

---

## 功能特点

- 📊 按月份统计代码贡献
- 📅 支持指定统计时间范围
- 👥 支持作者合并及自定义作者显示名称
- 📁 支持多个代码仓库合并统计
- 🔍 自动筛选指定扩展名的代码文件
- 🎨 彩色输出，直观展示代码增减情况
---

## 安装与使用

### 前提条件

- Git
- Bash (4.0+)
- AWK

### 安装

1. 下载脚本文件并添加执行权限：

    ```bash
    chmod +x git-code-stats.sh
    ```

2. 创建配置文件 `git-code-config.conf`，示例内容如下：

    ```ini
    [repos]
    /path/to/repo1
    /path/to/repo2

    [authors]
    username1 = 显示名称1
    username2 = 显示名称2
    ```

### 使用方法

- **基本使用：**

  ```bash
  ./git-code-stats.sh
  ```

- **指定时间范围和配置文件：**

  ```bash
  ./git-code-stats.sh -s 2025-01-01 -e 2025-05-31 -c my-config.conf
  ```

### 命令行选项

| 选项              | 说明                                         |
|-------------------|----------------------------------------------|
| `-s, --start DATE`| 起始日期 (默认: 当年开始，格式: YYYY-MM-DD)  |
| `-e, --end DATE`  | 结束日期 (默认: 今天，格式: YYYY-MM-DD)      |
| `-c, --config FILE`| 配置文件路径 (默认: git-code-config.conf)   |
| `-h, --help`      | 显示帮助信息                                 |



### 配置文件格式

配置文件采用简单的 INI 格式，包含两个部分：

- **仓库列表**  `[repos]`

 列出要统计的所有 Git 仓库路径，每行一个：

```ini
[repos]
/path/to/repo1
/path/to/repo2
```

- **作者映射**  `[authors]` 

定义 Git 用户名与显示名称的映射关系：

```ini
[authors]
john.doe = 张三
john.zhang = 张三
jane.smith = 李四
```


### 支持的文件类型与文件过滤

默认统计以下类型的文件：

- Java (`.java`)
- Go (`.go`)
- Python (`.py`)
- Vue (`.vue`)
- JavaScript (`.js`)
- TypeScript (`.ts`)
- JSX (`.jsx`)
- TSX (`.tsx`)
- WXML (.wxml)
- WXSS (.wxss)
- XML (.xml)
- YAML (.yml, .yaml)
- POM (.pom)
- ENV (.env)
- JSON (.json)

如需添加更多文件类型，可修改脚本中的 `CODE_EXTS` 数组。

** 文件过滤支持 **
脚本内置支持自动排除以下常见无需统计的文件类型：

- Protobuf 生成文件（如 *.pb.go, *.pb.gw.go, *.gen.go, *.pb.java）
- 压缩文件（如 *.min.js, *.min.css）

如需自定义排除其他文件类型，可修改脚本中的 `EXCLUDE_PATTERNS `数组。

### 输出示例

```
📝 代码提交月报
📅 时间范围: 2025-01-01 至 2025-05-31 
📁 仓库列表: 
    - /path/to/repo1
    - /path/to/repo2

🔍 正在分析仓库: /path/to/repo1
🔍 正在分析仓库: /path/to/repo2

📊 统计结果
────────────────────────────────────────────────────────────
   👤 作者        ➕ 新增    ➖ 删除    🔁 净变更  📌 贡献%
────────────────────────────────────────────────────────────
🟢 月份: 2025-01
   👤 张三        ➕ 1200    ➖ 300     🔁 +900    📌 60.0%
   👤 李四        ➕ 800     ➖ 200     🔁 +600    📌 40.0%
────────────────────────────────────────────────────────────
🟢 月份: 2025-02
   👤 张三        ➕ 900     ➖ 400     🔁 +500    📌 45.0%
   👤 李四        ➕ 1100    ➖ 300     🔁 +800    📌 55.0%
────────────────────────────────────────────────────────────
🔚 总计: 新增 4000 行, 删除 1200 行, 净变更 +2800

✅ 统计完成
```

---

## 工作原理

1. 解析命令行参数和配置文件
2. 遍历配置的仓库列表
3. 使用 Git 命令获取每个仓库的提交历史和代码变更
4. 用 AWK 处理和聚合数据
5. 按月份统计并展示每位作者的代码贡献情况

---

## 许可证

MIT License

---

## 贡献

欢迎提交 Issues 和 Pull Requests！

