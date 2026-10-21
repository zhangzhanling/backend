# 模块 A 实验目录

> 模块 A 以概念学习为主，实验的作用是**用最小操作验证概念真实存在**，不做大型实验。
> 每个实验 15–45 分钟，按顺序执行。完成实验后把记录写入 `STUDY_NOTES.md` 对应章节。

## 实验索引

| 编号 | 实验名称 | 验证的概念 | 预估用时 | 对应学习日 |
|------|----------|-----------|----------|-----------|
| 实验一 | 用 curl -v 观察 HTTPS 请求与 TLS 握手 | HTTPS/TLS 握手、HTTP 报文结构 | 30–45 分钟 | Day 4 |
| 实验二 | 用 dig/nslookup 观察 DNS 解析 | DNS 递归查询、记录类型、TTL | 15–30 分钟 | Day 5 |
| 实验三 | Linux 进程、端口与权限实操 | 进程信号、端口排查、rwx 权限 | 30–40 分钟 | Day 6–7 |

---

## 实验一：用 curl -v 观察 HTTPS 请求与 TLS 握手

### 目的

亲眼看到 TLS 握手发生在 HTTP 请求之前，观察证书信息，理解 HTTP 报文的真实样子。

### 步骤

1. 执行：

```bash
curl -v https://example.com
```

2. 依次观察输出中的这些段落（按出现顺序）：

```
*   Trying <IP>...            ← DNS 解析结果（TCP 连接目标）
* Connected to ...            ← TCP 三次握手完成
* TLS 里 certificate ...      ← 服务端证书下发
* SSL connection using ...    ← 协商出的加密套件/TLS 版本
* using HTTP/2 ...            ← 协议版本（注意 HTTP/2 或 HTTP/1.1）
> GET / HTTP/2                ← 请求行开始
> Host: example.com           ← 请求头
>                            ← 空行，之后是请求体（GET 无体）
< HTTP/2 200                  ← 状态行
< content-type: ...           ← 响应头
<                            ← 空行 + 响应体
```

3. 再执行观察证书详情：

```bash
curl -vI https://example.com 2>&1 | findstr /i certificate
# 或在 Linux/WSL 下：
echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

### 预期结果与观察点

- [ ] 能指出输出中"TCP 连接完成"和"HTTP 请求发出"分别在哪一行，确认 TLS 在两者之间。
- [ ] 记录下：TLS 版本、协商的加密算法、证书 Subject 与 Issuer、有效期。
- [ ] 能找到请求行、至少 3 个请求头、状态行、至少 3 个响应头。

### 失败排查

- 公司网络/代理环境导致超时 → 换网络或设置 `curl -v --noproxy '*' https://example.com`。
- 输出被截断看不到证书 → 确认用了 `-v` 而非 `-s`；Windows 下建议在 PowerShell 中重定向到文件再打开：`curl -v https://example.com > trace.txt 2>&1`。

### 反例观察（加做 5 分钟）

```bash
curl -v http://example.com     # 明文 HTTP
```

对比：没有证书段落、请求头明文可见。思考：这条连接上银行密码会怎样？

---

## 实验二：用 dig/nslookup 观察 DNS 解析

### 目的

验证 DNS 是在 TCP 连接之前发生的独立步骤，观察记录类型与 TTL。

### 步骤

1. Linux/WSL 下执行（Windows 可用 `nslookup example.com`）：

```bash
dig example.com          # 默认查 A 记录
dig example.com CNAME    # 查指定类型
dig +trace example.com   # 观察从根到权威的迭代过程（重点）
```

2. Windows 下替代命令：

```nslookup example.com
nslookup -type=CNAME www.github.com
```

3. 对比 TTL 与缓存：连续两次 `dig example.com`，观察第二次的 `QUERY TIME` 是否显著变小（命中本地/系统缓存）。

### 预期结果与观察点

- [ ] `dig` 输出中的 `QUESTION SECTION`、`ANSWER SECTION`、`AUTHORITY SECTION` 各是什么角色。
- [ ] `dig +trace` 能看到根（.）、顶级域（com.）、权威服务器的逐级响应。
- [ ] 记录一条 A 记录的 IP 和 TTL 值。
- [ ] 理解 `www` 常是 CNAME 而非直接 A 记录。

### 失败排查

- `dig` 命令不存在 → Windows 用 `nslookup`；WSL 内 `sudo apt install dnsutils`。
- `+trace` 输出过长 → 管道给 `less`：`dig +trace example.com | less`。

### 反例观察（加做 5 分钟）

```bash
ping does-not-exist-abc123.com
```

观察域名解析失败的报错，与"连接被拒绝"（端口问题）报错对比——两类错误发生在链路的不同环节。

---

## 实验三：Linux 进程、端口与权限实操

### 目的

掌握线上排查最小命令集：找进程、找端口、发信号、改权限。验证 kill 信号差异与权限位语义。

### 环境要求

Windows 本机可使用 WSL2（推荐 Ubuntu 发行版）或 Git Bash；没有 Linux 环境时，可用 PowerShell 完成前两步的替代版本（已标注）。

### 步骤

**A. 启动服务并找到它**

```bash
# 在一个终端启动一个简单 HTTP 服务（Python 自带）
python3 -m http.server 8080
# 或 Node：
# npx http-server -p 8080
```

另一个终端查看端口与进程：

```bash
ss -lntp | grep 8080        # Linux/WSL
# Windows PowerShell 替代：
# netstat -ano | findstr :8080
```

记下 PID，再看进程详情：

```bash
ps aux | grep http.server   # 或 ps -p <PID> -o pid,ppid,%mem,cmd
```

**B. 对比两种 kill 信号**

```bash
kill -TERM <PID>            # 优雅退出（15）
# 重启服务后：
kill -9 <PID>               # 强制杀死（9）
```

观察：`kill -TERM` 时进程有机会执行清理逻辑（如 Node 服务打印 shutdown 日志）；`kill -9` 立即消失，端口可能残留。

**C. 文件权限验证**

```bash
mkdir perm-lab && cd perm-lab
echo "secret" > config.json
chmod 600 config.json && ls -l config.json   # -rw------- 仅属主可读写
chmod 755 run.sh && ls -l run.sh             # 属主可执行，其他人可读可执行
echo 'echo hello' > run.sh && chmod 755 run.sh && ./run.sh
chmod 644 run.sh && ./run.sh                 # 预期：Permission denied（无 x）
ls -l config.json                            # 第一列 -rw------- 如何读？
```

**D. 日志实时过滤（为模块 G 预热）**

```bash
# 制造日志
for i in $(seq 1 20); do echo "$(date) INFO request-$i" >> app.log; done
echo "$(date) ERROR database timeout" >> app.log
tail -f app.log | grep --line-buffered ERROR
# 另开终端追加一条 ERROR，观察实时输出；Ctrl+C 结束
grep -c "INFO" app.log        # 统计行数
```

### 预期结果与观察点

- [ ] 能通过端口号找到 PID，再通过 PID 找到命令行。
- [ ] 观察到 TERM 与 KILL 的退出行为差异。
- [ ] 理解 `ls -l` 第一列 10 个字符的含义（类型 + 属主/属组/其他人 rwx）。
- [ ] 无 x 权限的脚本无法执行，即使有 r 权限（读 ≠ 可执行）。
- [ ] `tail -f | grep` 能实时看到新增的 ERROR 行。

### 失败排查

- `ss`/`dig`/`python3` 命令不存在 → WSL 内 `sudo apt update && sudo apt install iproute2 dnsutils python3`。
- Windows 无 WSL → 用 PowerShell 版本的 `netstat -ano | findstr :8080` 和 `Stop-Process -Id <PID>` 完成 A/B 步骤，权限部分跳过并在笔记中记录"待 WSL 环境补做"。
- `kill` 后端口仍在 → 正常，观察 `ss -lntp` 是否进入 TIME_WAIT 或立即释放，记录下来。

---

## 实验记录规范

每个实验完成后，在 `STUDY_NOTES.md` 中按以下格式记录：

```markdown
## 实验 N 记录：<名称>
- 日期：
- 执行的命令：
- 关键输出（截取）：
- 我观察到的 / 验证了什么：
- 与预期不符的地方及原因：
- 用一句话总结它证明了哪个概念：
```

## 不安排的实验（说明）

以下模块 A 概念不设实验，属于纯知识点学习，按 `STUDY_GUIDE.md` 通过"口述 + 自查问题"验收：

- HTTP 缓存协商的完整矩阵（机动周按需用 DevTools 补充观察即可）；
- 进程/线程/协程对比（无实验价值，概念辨析为主）；
- epoll/select/poll 工作机制（P2 内容，只做概念了解）。
