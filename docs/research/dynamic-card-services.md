# GitHub Profile README 动态卡片服务调研

> 调研日期：2026-08-15（Asia/Shanghai）
> 调研范围：仅使用官方仓库、源码、项目文档和实际服务端点。单次实测只能验证当时可用性，不等同于 SLA。

## 结论

目前没有找到一个可以负责任地推荐、且比 `stats.justsong.cn` 更稳定的 **CSDN 实时卡片托管服务**。唯一找到的可直接替换候选 `stats-ts-cards` 复刻了相同的关键失效模式：Vercel 请求内实时抓取 CSDN，只使用进程内 LRU 缓存；实测冷链路同样返回 504。

如果需要保留 CSDN 统计，仍建议采用「定时更新、仓库内保留上次成功 SVG」。它对读者仍是自动更新的，但不再把每次 README 访问绑定到 CSDN 抓取的实时成功上。

如果只是替换现有的 GitHub 卡片，有两个明显更好的托管候选：

1. [GitHub Profile Summary Cards](https://github.com/vn7n24fzkq/github-profile-summary-cards)：稳定性设计最完整，包含 CDN、持久 Redis 数据缓存、stale 回退和 token 切换。
2. [GitHub Stats Extended](https://github.com/stats-organization/github-stats-extended)：活跃维护的 `github-readme-stats` 继任者，兼容原有 URL 参数并实现重试与 stale-while-revalidate。

它们都不支持 CSDN。

## 候选对比

| 服务/项目 | CSDN | GitHub README 直接 `<img>` | 维护状态 | 缓存/降级机制 | 2026-08-15 实测 | 建议 |
|---|---:|---:|---|---|---|---|
| [`stats.justsong.cn`](https://github.com/songquanpeng/stats-cards) | 是 | 是 | 最后仓库提交 2025-02-03 | 进程内 LRU，默认 100 分钟；无持久 stale | 原 URL：200 / 0.397s；新查询冷请求：504 / 11.879s | 不继续作为访问时实时依赖 |
| [`HarryYe66/stats-ts-cards`](https://github.com/HarryYe66/stats-ts-cards) | 是 | 是 | 最后提交 2024-08-05，16 commits / 1 star | 进程内 LRU，默认 100 分钟；CSDN 在请求内通过 Axios 抓 HTML | 常规 URL：200 / 3.417s；新查询冷请求：504 / 12.881s | **不推荐**，不是稳定性升级 |
| [`GitHub Profile Summary Cards`](https://github.com/vn7n24fzkq/github-profile-summary-cards) | 否 | 是 | 最后提交 2026-08-07，426 commits / 3.6k stars | CDN + Upstash Redis；持久 stale；GitHub 错误时返回旧数据；token 回退 | 200 / 2.104s，返回有效 SVG | **推荐替换 GitHub 卡片** |
| [`GitHub Stats Extended`](https://github.com/stats-organization/github-stats-extended) | 否 | 是 | 最后提交 2026-08-15，2,684 commits / 857 stars | 成功卡默认长缓存 + 1 天 SWR；错误卡短缓存 + 1 天 SWR；GitHub 请求重试 | 200 / 2.373s，返回有效 SVG | **推荐替换 GitHub 卡片** |
| [`lxKylin/data-card`](https://github.com/lxKylin/data-card) | 是 | 读取已生成文件 | 最后提交 2024-02-03，113 commits / 0 stars | GitHub Actions 定时生成并提交图片，不是在线卡片 API | 未作为服务端点测试 | 只作实现参考，不建议新增对其依赖 |

## CSDN 直接替代调查

### 1. `stats-ts-cards` 可访问，但失效模式没有改变

项目 README 明确宣称支持 CSDN，并提供 `stats-ts-cards.vercel.app` / `stats-cards-beige.vercel.app` 部署。但源码显示：

- [CSDN crawler](https://github.com/HarryYe66/stats-ts-cards/blob/main/crawler/csdn.ts) 在每个缓存 miss 上用 Axios 实时请求 `https://blog.csdn.net/{name}` 并解析 HTML；没有明确请求超时、有限重试或持久的最后成功数据。
- [cache.ts](https://github.com/HarryYe66/stats-ts-cards/blob/main/common/cache.ts) 使用 Node 进程内 `lru-cache`，默认 TTL 100 分钟。Serverless 新实例不会继承旧实例的内存。
- [api/csdn.ts](https://github.com/HarryYe66/stats-ts-cards/blob/main/api/csdn.ts) 只在 LRU miss 时调用 crawler，然后才把结果写入缓存。如果 crawler 等待时间超过 Vercel 函数上限，请求在来得及写缓存前就会 504。

实测同一账号 `qq_41048567`：

- [`stats-ts-cards` 常规 URL](https://stats-ts-cards.vercel.app/api/csdn?id=qq_41048567)：HTTP 200，3.417s，SVG 中数据有效。
- 添加一个新查询值以避开现有 CDN 键：HTTP 504，12.881s，Vercel 报 `FUNCTION_INVOCATION_TIMEOUT`。
- README 列出的 `stats-cards-beige.vercel.app` 也在冷请求上返回同类 504。

因此，它的「命中缓存时正常，冷请求时可能超时」与当前服务相同，换域名不会从根本上解决问题。

### 2. `data-card` 是「定时快照」，不是托管 API

[`lxKylin/data-card` README](https://github.com/lxKylin/data-card) 展示了支持 CSDN 的 GitHub Action：定时抓数据、生成卡片，再提交回仓库。它印证了方案 1 的可行性，但项目本身已较久未维护，不宜成为新的外部依赖。更可控的做法是在 `CoffeeCheese` 仓库内保留一个小型 workflow：只有获取成功且 SVG 验证通过才替换旧文件。

## 可用的 GitHub 卡片服务

### GitHub Profile Summary Cards：稳定性机制最完整

项目的 [README/API 文档](https://github.com/vn7n24fzkq/github-profile-summary-cards) 明确支持直接将托管 SVG 放入 README，也同时提供 GitHub Action。其 [caching architecture](https://github.com/vn7n24fzkq/github-profile-summary-cards/blob/main/docs/architecture/caching.md) 记录了：

- 第一层是 Vercel CDN；成功卡的当前源码缓存头为 `max-age=14400, s-maxage=172800, stale-while-revalidate=604800`，见 [`src/const/cache.ts`](https://github.com/vn7n24fzkq/github-profile-summary-cards/blob/main/src/const/cache.ts)。
- 第二层是 Upstash Redis 数据缓存，跨部署保留，主题/颜色变体共用同一数据项。
- GitHub API 错误时可用 stale 数据继续渲染正常卡片；Redis 错误时 fail-open。
- GitHub token 在 401/403/429 时可切换后备 token。

实测 [`stats` 端点](https://github-profile-summary-cards.vercel.app/api/cards/stats?username=CoffeeCheese&theme=github)：HTTP 200，2.104s，SVG 包含 CoffeeCheese 的 stars、commits、PR、issues 等数据。

### GitHub Stats Extended：活跃的兼容继任者

`github-readme-stats` 的 [官方仓库](https://github.com/anuraghazra/github-readme-stats) 现已明确标记「不再维护」，并指向 [GitHub Stats Extended](https://github.com/stats-organization/github-stats-extended) 作为活跃继任者。继任项目的 README 说明只需将域名替换为 `github-stats-extended.vercel.app` 即可迁移。

稳定性相关实现：

- [`apps/backend/src/common/cache.js`](https://github.com/stats-organization/github-stats-extended/blob/master/apps/backend/src/common/cache.js) 默认将 stats 卡缓存 10 小时，并附加 1 天 `stale-while-revalidate`；错误响应使用更短的 10 分钟缓存，同样附加 1 天 SWR。
- [`packages/core/src/common/retryer.ts`](https://github.com/stats-organization/github-stats-extended/blob/master/packages/core/src/common/retryer.ts) 被 stats、repo、gist、top languages 等 fetcher 共用，用于 GitHub 请求重试/token 切换。

实测 [`api` 端点](https://github-stats-extended.vercel.app/api?username=CoffeeCheese&theme=transparent)：HTTP 200，2.373s，返回有效 SVG。

## 推荐决策

### 如果目标是「CSDN 卡片必须保留」

采用方案 1，不迁移到 `stats-ts-cards`：

1. README 始终引用仓库内 `assets/csdn-stats.svg`。
2. GitHub Actions 每天或每周获取一次。
3. 仅当 HTTP 200、`Content-Type`/SVG 内容正确、关键文本存在且文件大小合理时才原子替换。
4. 任何 504、HTML 错误页、空 SVG 或数据验证失败都保留上一版。

这个设计把不稳定抓取从「每位访客的图片请求」移到「可重试、可验证、失败可回退的后台任务」。

### 如果目标是「最少改动替换 GitHub 卡片」

- 首选 `GitHub Stats Extended`：形式最接近现在的 stats 卡。
- 如果更看重有文档的持久 stale 数据回退，选 `GitHub Profile Summary Cards`。

两者均可直接嵌入 GitHub Profile README，但不能替代 CSDN 统计。

## 限制

- 不存在可公开验证的服务 SLA；本报告对「稳定」的判断主要来自可审查的缓存/回退实现、维护活跃度和当日端点实测。
- GitHub Camo 会再加一层图片代理和缓存；直连测试不完全等同于 GitHub 页面内的端到端延迟，但能识别服务本身的 200/504 和 SVG 有效性。
- 项目热度不等同于可用性；star 只用作生态规模背景，未被当作独立的稳定性证据。
