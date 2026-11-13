# 上游文件改动登记簿

## 这个文件解决什么问题

同步上游时，冲突只发生在「你和上游都改过的文件」上。新增文件永远不冲突，**改上游文件才是成本的来源**。

所以每次动上游已有文件，都在这里登记一条。同步遇到冲突时，不用现场读 diff 猜意图，直接照记录重放即可。

## 使用规则

1. **改之前登记，不是改之后**。写下来能让你先想清楚「这处非改不可吗」。
2. 只登记 `backend/`、`frontend/`、`backend-mcp/` 下的上游文件。自己新建的文件不用登记。
3. 同步完成后更新「状态」列：`待验证` → `已随上游重建`。
4. 如果某处改动后来被上游原生实现了，把这条记录标记为 `可移除` 并删掉自己的补丁——这是最理想的结果。

## 登记表

| # | 文件 | 改动摘要 | 为什么改 | 登记日期 | 状态 |
|---|---|---|---|---|---|
| — | — | 暂无登记 | — | — | — |

## 单条记录模板

需要详细信息时，在表格下方按这个格式补充：

```md
### #1 backend/app.py

- **改动位置**：`register_blueprints()` 函数末尾，新增一行
  `app.register_blueprint(my_feature_bp, url_prefix="/api/my")`
- **上游原始代码**（改之前的锚点，用于冲突时定位）：
  ```python
  # 原文上下文
  ```
- **为什么不能放新文件**：路由注册必须在 app 初始化时执行
- **冲突时的处理**：上游若重构了 `register_blueprints`，找到新的注册入口，把这一行搬过去
- **关联提交**：`a1b2c3d` feat(local): 接入自有发布渠道
```

## 风险提示

以下文件上游 90 天内改动超过 8 次，登记后要格外留意（数据来自 `git log` 统计）：

| 文件 | 90天改动次数 |
|---|---|
| `frontend/src/views/PublishCenter.vue` | 21 |
| `backend/impl/channels/platform.py` | 12 |
| `backend/impl/weixin_gzh/platform.py` | 11 |
| `backend/app.py` | 11 |
| `frontend/src/views/ArticlePublish.vue` | 9 |
| `backend/services/draft_merge.py` | 9 |
| `backend/impl/bilibili/platform.py` | 9 |
| `backend/ext_api/__init__.py` | 9 |
