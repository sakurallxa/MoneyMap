# MoneyMap · 字体使用规则

本文档说明 App 内的字体分工、字重映射、type token,以及"什么场景该用哪个 API"。
任何与本文档不一致的写法都属于待清理项。

---

## 1. 字体家族

| 用途 | 字体 | 来源 |
|---|---|---|
| 中文 / 标点 | **思源宋体 SC** (Source Han Serif SC) | 项目内打包 4 个 OTF,运行时 `CTFontManagerRegisterFontsForURL` 注册 |
| 数字 / 货币符号 / 百分号 / 字母代码 (AAPL 等) | **SF Pro** (system) | iOS 内置 |
| Fallback(思源宋体不可用时) | **Songti SC** → 系统 `.serif` design | iOS 内置 |

**核心原则:**
- 中文一律走衬线,以呼应"钱袋"品牌的拟物感
- 数字走 SF,因为思源宋体没有 Bold/Heavy,数字渲染重量级不够
- 永远不要把"¥"以外的货币符号塞进衬线字体里

---

## 2. 字重映射(关键)

**思源宋体 SC 只有 ExtraLight / Light / Regular / Medium 四档,没有 Bold/Heavy。**

为了避免 SwiftUI 在 `.heavy` / `.bold` 等"超重"字重上做 synthetic bold(合成伪粗,看起来脏),
项目里所有 `Theme.serif(_:weight:)` 调用都会被 [`SerifWeightMap`](../MoneyMap/Utils/Theme.swift) 拦截,
直接返回对应字重的真实 OTF PostScript 名,跳过 `.weight()` 调用。

### 映射表

| SwiftUI Font.Weight | 实际使用的 OTF |
|---|---|
| `.ultraLight` / `.thin` | `SourceHanSerifSC-ExtraLight` |
| `.light` | `SourceHanSerifSC-Light` |
| `.regular` | `SourceHanSerifSC-Regular` |
| `.medium` | `SourceHanSerifSC-Medium` |
| `.semibold` | `SourceHanSerifSC-Medium` ← 注意降级 |
| `.bold` / `.heavy` / `.black` | `SourceHanSerifSC-Medium` ← 注意降级 |

### 这意味着什么?

**视觉上,中文 `.bold` 看起来和 `.medium` 一模一样。** 你写 `Theme.serif(30, weight: .heavy)`
得到的是 Medium 字形,不是真的 Heavy。

**推荐做法:**

1. 中文衬线只用两档:**Regular(正文)** + **Medium(强调/标题)**
2. 写 SwiftUI 时仍可以写 `.semibold` / `.bold` / `.heavy`,运行时会自动降级到 Medium
   —— 这样代码读起来仍然有层级语义,而真实渲染没有伪粗污染
3. 如果**真的需要更重的中文**,考虑改用 SF 中文(`.system(...).weight(.heavy)`)。
   SF 中文有完整字重表,可以渲染真正的 Heavy。但目前钱袋全局走宋体,不混搭
4. 数字旁边的中文标签**不要**写 `.heavy`,否则视觉上数字永远压过中文

---

## 3. Type Token(推荐入口)

`Theme.TypeToken.*` 收敛了"小标题 / eyebrow / caption"这种碎片化场景。
请优先用这些 token,**不要直接写 `Theme.serif(11, weight: .semibold)`** 之类的字面量字号:

```swift
// ✅ 好
Text("总资产 · TOTAL")
    .font(Theme.TypeToken.eyebrow())
    .kerning(Theme.TypeToken.eyebrowKerning)

// ❌ 差(同样信息层级却字号/字距各自发挥)
Text("总资产 · TOTAL")
    .font(.system(size: 11, weight: .semibold))
    .kerning(1.6)
```

### Token 一览

| Token | size / weight / kerning | 用法 |
|---|---|---|
| `Theme.TypeToken.eyebrow(_:)` | 11 / .semibold / 1.6 | 卡片顶部 ALL-CAPS 标签 |
| `Theme.TypeToken.caption(_:)` | 11 / .regular / 0 | 副信息小字 |
| `Theme.TypeToken.label(_:)` | 13 / .semibold / 0 | 列表行内的标签/副字段 |

---

## 4. API 入口

| 场景 | 用什么 |
|---|---|
| SwiftUI Text 字体 | `Theme.serif(_:weight:)` |
| `NavigationBar` / `UITabBar` appearance | `Theme.uiSerif(size:bold:)` |
| 环境字体注入 | `Theme.serifBody`(在 MoneyMapApp 根 `.environment(\.font, ...)` 已注入) |
| 类型 token | `Theme.TypeToken.eyebrow/caption/label` |
| 金额渲染 | **`MoneyText(value: scale: hidden:)`** ← 不要再写 `Text("¥...")` |
| 百分比渲染 | **`PercentText(value: hidden:)`** |

`MoneyText` 内部已经把 ¥ 与数字的字号比例锁死(¥ = 数字 × 55%),所有钱的地方走它一个组件即可。

---

## 5. 数字字体规则

- **永远不要把数字塞进 `Theme.serif`**:Songti SC / 思源宋体的数字字形是中文调,在金融上下文里会显得"古旧"
- **永远要加 `.monospacedDigit()`** :金额、份额、百分比等需要纵向对齐的地方都要等宽
- **货币符号 "¥"** 用 SF Pro Bold,字号是相邻数字的 55%(MoneyText 已锁死)
- **字母代码**(基金代码 005827 / 美股 AAPL)用 SF + `.monospacedDigit()`

---

## 6. 何时打破规则

只有 Hero PnL 卡的米→金 gradient 字数字保留 `.foregroundStyle(LinearGradient)` 这种特殊渲染,
其他所有地方应该尊重上述规则。如果你觉得规则不够用,**请先提议扩展 token,而不是绕过它**。
