# 二次开发与上游同步指南

> 适用仓库：`DevilJie/QianFan-Sync`（千帆云递）
> 本文档描述本目录的 fork 工作流。所有命令都在仓库根目录执行。

---

## 一、核心结论

**上游只动 `master`，你只动 `dev`，中间靠 rebase 把你的改动「抬到」最新上游之上。**

- 你的 fork（`fanxinliuchen/QianFan-Sync`）只当**备份盘**用，同步动作永远在本地做。
- 同步的动作只有一条命令：`./sync-upstream.sh`
- **绝对不要**在 `start.bat` 的「是否更新」提示里按 `Y`（原因见第四节）。
- GitHub 网页上的 `Sync fork` 按钮**不是必需环节**，别把它当成同步手段（原因见第八节）。

---

## 二、当前仓库已配置好的状态

| 项 | 值 | 说明 |
|---|---|---|
| `upstream` 远程 | `ghproxy.net` 镜像 → 官方仓库 | 直连 GitHub 不通，走镜像；push 地址被设为 `NO_PUSH_ALLOWED` 防误推 |
| `origin` 远程 | `github.com/fanxinliuchen/QianFan-Sync`（你的 fork） | `dev` 推到这里做备份；`master` 也推了一份镜像 |
| `master` 分支 | 与上游完全一致，跟踪 `upstream/master` | **只做只读镜像，永远不在这里提交** |
| `dev` 分支 | 当前所在分支 | **所有二次开发都在这里做** |
| 下载源 | 脚本内置 3 个候选，自动探测 | ghproxy.net / ghfast.top / 直连 GitHub，按序探测，失效自动切换 |

额外开启的 git 配置（都为长期跟进上游服务）：

| 配置 | 作用 |
|---|---|
| `rerere.enabled=true` | 记住你解过的冲突，下次上游改同一处时自动套用 |
| `merge.conflictstyle=zdiff3` | 冲突里额外显示原始版本，判断该留谁更容易 |
| `rebase.autoStash=true` | 变基前自动暂存未提交改动，结束后自动还原 |
| `core.autocrlf=false` | 避免 Windows 行尾转换把整个文件变成「全文件改动」 |

---

## 三、日常操作（三条命令）

```bash
# 1. 开工前确认在 dev 分支
git checkout dev

# 2. 想同步上游时，先看不动手（会列出上游新提交 + 冲突预警）
./sync-upstream.sh --check

# 3. 确认没问题再真正同步
./sync-upstream.sh
```

启动服务用 `dev-start.bat`（Windows）或 `./dev-start.sh`（Linux/macOS），**不要直接用 `start.bat`**。

### 提交习惯

```bash
git add -A
git commit -m "feat(本地): 改成我们公司的发布流程"
```

一句话一个提交，别攒成巨型提交。理由很实际：变基冲突是按提交逐个解的，一个提交混了 20 个文件，冲突时你根本分不清哪部分该留。

---

## 四、危险清单（必读）

### 1. 启动脚本的「更新」会毁掉你的改动

`start.bat` / `start.sh` / `update.sh` 里都有这段逻辑：

```bat
git remote set-url origin https://github.com/DevilJie/...
git checkout -f master
git reset --hard origin/master
```

触发条件是**你手动输入 Y**。后果有三层：

1. `checkout -f master` 把你从 `dev` 强制切回 `master`；
2. `reset --hard` 清空所有未提交改动；
3. `set-url origin` 会把 `origin` 改回官方地址（你以后配了自己的仓库也会被改掉）。

脚本自己的提示也只写了「更新将覆盖本地修改」，没提会切分支、改远程。

**对策**：用 `dev-start.bat` / `dev-start.sh` 启动。它们只做一件事——设 `SAU_JUST_UPDATED=1`，让 `start.bat` 直接跳过整段更新逻辑，其余行为完全一致。没有修改上游任何文件，所以不会产生冲突。

### 2. `data/` 目录不进 git，但里面有你的账号状态

`data/` 下存着 cookies、SQLite 数据库、素材、日志。`.gitignore` 已排除，所以：

- 同步上游**不会**动你的登录态和素材，这是好事；
- 但也意味着**换机器要单独备份 `data/`**，git 帮不了你。

备份命令：

```bash
tar -czf ../qianfan-data-$(date +%Y%m%d).tar.gz data/
```

### 3. 别改 `.gitignore` 和 `start.bat`

这两类文件上游也在改。如果你需要额外的忽略规则，写到 `.git/info/exclude`（本地生效、不进版本库）；如果一定要改 `.gitignore`，改完立刻登记到 `PATCHES.md`。

---

## 五、改哪里最省冲突（基于近 90 天上游真实提交统计）

上游非常活跃：**近 30 天 48 次提交，90 天内改动集中在少数几个文件**。选址比技巧更重要。

### 冲突风险分级

| 层级 | 做法 | 冲突概率 | 典型例子 |
|---|---|---|---|
| 🟢 零冲突 | **新增独立文件**，不改任何已有文件 | 几乎为 0 | 新建 `backend/impl/新平台/platform.py`、新建前端页面组件 |
| 🟡 低冲突 | 在**列表末尾追加一行**的注册类改动 | 低 | 在 `backend/impl/registry.py` 的 `imports` 列表加一个元组 |
| 🟠 中冲突 | 改配置、常量、独立工具函数 | 中 | `frontend/src/config/`、`backend/impl/platform_meta.py` |
| 🔴 高冲突 | 改核心流程文件 | **必然冲突** | 见下表 |

### 上游改动最频繁的文件（90 天内，非合并提交）

| 次数 | 文件 | 建议 |
|---|---|---|
| 21 | `frontend/src/views/PublishCenter.vue` | 发布中心主页，改动最猛。**尽量不要改**；要加面板就新建组件，用插槽/条件渲染挂进去 |
| 12 | `backend/impl/channels/platform.py` | 视频号。要定制就继承覆盖，别原地改 |
| 11 | `backend/impl/weixin_gzh/platform.py` | 公众号，同上 |
| 11 | `backend/app.py` | Flask 入口。加路由优先建**新蓝图**，在 `blueprints/` 下新建文件 |
| 9 | `frontend/src/views/ArticlePublish.vue` | 文章发布页 |
| 9 | `backend/services/draft_merge.py` | 草稿合并逻辑 |
| 9 | `backend/impl/bilibili/platform.py` | B站 |
| 9 | `backend/ext_api/__init__.py` | 异步任务注册 |
| 7 | `backend/ext_api/task_queue.py` | 任务队列 |
| 6 | `frontend/src/views/Settings.vue` | 设置页 |

### 推荐的三层改造法

**第一层：新增平台（最典型的扩展场景，零冲突）**

这个项目是 Registry 模式，加平台的成本极低：

```bash
mkdir -p backend/impl/myplatform
# 1. 复制一个现有平台当模板
cp backend/impl/zhihu/platform.py backend/impl/myplatform/platform.py
# 2. 改类名、platform_key、platform_name 和实现
# 3. 在 registry.py 的 imports 列表末尾追加一行：
#    (22, ".myplatform.platform", "MyPlatform"),
```

第 3 步是唯一碰上游文件的地方，加在列表末尾，冲突概率极低。

**第二层：新增功能模块**

- 后端：`backend/blueprints/your_feature_bp.py` 新建蓝图 → 只需在 `app.py` 加一行 `register_blueprint`
- 前端：`frontend/src/views/YourView.vue` 新建页面 → 只改 `router/index.js` 加一条路由
- 如果连这两行都不想改，可以把注册逻辑写进一个独立文件，用一个启动钩子导入它

**第三层：必须改上游文件时**

改之前先登记到 `PATCHES.md`（格式见该文件），写清楚：改哪个文件、改了什么、为什么、上游这段代码长什么样。同步时如果冲突，直接照着记录重放，比读 diff 快得多。

---

## 六、同步冲突的处理流程

`./sync-upstream.sh` 遇到冲突会停下来并列出文件。标准动作：

```bash
# 1. 看冲突范围
git status

# 2. 逐个文件解决，搜索冲突标记
#    <<<<<<< HEAD        你的改动
#    ||||||| merged common ancestors   原始版本（zdiff3 提供）
#    =======
#    >>>>>>> upstream/master   上游的改动

# 3a. 按「上游逻辑为主 + 把你的改动重新贴上去」的原则编辑

# 3. 标记已解决并继续
git add <冲突文件>
git rebase --continue

# 中途想全部放弃
./sync-upstream.sh --abort
```

**判断原则**：这个仓库的上游是在持续演进的，他们的重构通常比你的补丁更合理。所以冲突时**别想着保住自己的旧代码，而是先接受上游的新写法，再把你的意图重新实现一遍**。这样每次同步后代码质量是上升的，否则你会越拖越难合。

如果某个提交反复冲突、你又不想每次重解，可以考虑把它单独拿出来做成一个"本地补丁文件"（`git format-patch`），需要时再 `git am` 打上。

---

## 七、改动备份：`origin` 已接上你的 fork

本地只有一份 `dev` 分支是有风险的（磁盘坏了就全没了），所以 `origin` 已指向你自己的 fork：

```
origin   https://github.com/fanxinliuchen/QianFan-Sync.git   ← 你的，可读可写
upstream https://ghfast.top/https://github.com/DevilJie/QianFan-Sync.git  ← 官方，只读
```

分支跟踪关系是刻意这样设的：

| 本地分支 | 跟踪 | 含义 |
|---|---|---|
| `master` | `upstream/master` | 只读镜像，`git status` 直接告诉你落后官方多少 |
| `dev` | `origin/dev` | 你的开发线，`git status` 告诉你有没有没备份的提交 |

每次同步完把改动推上去：

```bash
git push --force-with-lease origin dev
```

变基会重写提交历史，所以必须强推。用 `--force-with-lease` 而不是 `--force`，它在远端有别人的新提交时会拒绝，避免覆盖。

> 想把 `master` 也更新到 fork 上，`git push origin master` 即可（这条永远不需要强推，因为它是纯镜像）。

---

## 八、关于 GitHub 的「Sync fork」按钮

**结论：对二次开发没有实际作用，而且不要依赖它。**

它做的事只有一件：把你 fork 里的**默认分支**（这里是 `master`）快进到上游最新。就这些。

三个关键事实：

**1. 它不碰你的 `dev`。**
你点一百次 Sync fork，`dev` 分支上的改动也不会自动变基到最新上游。而让改动适配最新上游的动作，只有本地的 `./sync-upstream.sh`。

**2. 你本地的同步根本不经过 fork。**
`git fetch upstream` 是直连官方仓库拉取的，跟你 fork 的 `master` 是否落后**完全无关**。所以"fork 落后了"这件事，不影响你任何本地操作。

**3. 远程 dev 和本地 dev 是两回事。**
你推上去的 `origin/dev` 只是备份，同步永远在本地做，做完再强推覆盖它。

### 什么情况下值得点

| 场景 | 值得点吗 |
|---|---|
| 日常开发、同步上游 | 不需要 |
| 想在 GitHub 网页上直观看到「我的 fork 和官方差多少」 | 可以点 |
| 准备给上游提 PR | 需要，先同步再基于最新发 PR |
| 只是想仓库列表看起来整洁 | 随你，纯装饰 |

### 一个要避开的风险

如果哪天你把 `dev` 设成了 fork 的**默认分支**，再点 Sync fork，GitHub 会发现 `dev` 上有你自己的提交，提示 `Discard N commits`。手一抖点下去，远程 `dev` 就被重置成上游代码了。

所以：**让 fork 的默认分支始终是 `master`**，`dev` 只作为普通分支存在。这样 Sync fork 按钮永远只会动那个没有你改动的镜像分支，点了也无害。

---

## 九、常见问题

**Q：同步后发现改坏了，怎么回退？**
每次同步前脚本会自动打一个 `sync-backup-<时间戳>` 标签：
```bash
git tag -l "sync-backup-*" | tail -3
git reset --hard sync-backup-20261113-090000
```

**Q：镜像挂了、脚本报「所有源都连不上」？**
两个办法：

1. 临时指定一个可用地址（跳过自动探测）：
   ```bash
   SYNC_SRC=https://kkgithub.com/DevilJie/QianFan-Sync.git ./sync-upstream.sh
   ```
2. 长期修改：编辑 `sync-upstream.sh` 顶部的 `CANDIDATES` 数组。

脚本每次运行都会逐个探测，只有可用的才会被采用——实测镜像波动很大（同一天内 ghproxy.net 有时可用有时 502），所以别写死一个源。

**Q：我可以直接改 `master` 分支吗？**
不要。`master` 是纯镜像，本地和 fork 上都一样，你在上面提交后，下次 rebase 到上游会因为历史分叉而变复杂。所有改动放 `dev`。同理，也**不要在 GitHub 网页上直接编辑 fork 的 `master`**，那会让镜像失真。

**Q：上游更新太频繁，每周都冲突怎么办？**
说明你的改动落在高危文件上了（对照第五节表格）。两个选择：一是把改动挪到新增文件里；二是降低同步频率到每两周一次，但每次要解决更多冲突——**频率越高，单次冲突越小**，通常每周同步反而更轻松。

**Q：想给上游提 PR 呢？**
从 `dev` 拉一个干净分支，只放那个特性的提交，推到自己的 fork，然后在 GitHub 上向官方发 PR：

```bash
git checkout -b pr/my-feature upstream/master
git cherry-pick <你的提交>
git push -u origin pr/my-feature
```

推送后 GitHub 会给出 `Compare & pull request` 链接，目标选 `DevilJie/QianFan-Sync:master`。

**Q：`update.sh` 还能用吗？**
不能用于更新本项目。它的作用是把代码重置成官方最新版，会抹掉你的改动。只在「我想彻底放弃本地改动、回到纯上游」时才用它。日常同步一律用 `./sync-upstream.sh`。
