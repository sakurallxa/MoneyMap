# Widget 添加步骤

桌面 Widget 代码已写好,但因为 Widget Extension 是一个**独立的 Xcode Target**,需要你在 Xcode UI 里手动加上(2 分钟搞定)。

## 步骤

### 1. 在 Xcode 里新建 Widget Extension Target

1. 双击打开 `MoneyMap.xcodeproj`
2. 顶部菜单 **File → New → Target...**
3. 模板选 **Widget Extension**(在 Application Extension 分类下),点 **Next**
4. 填写:
   - Product Name: `MoneyMapWidget`
   - Team: 选你的 Apple ID
   - Bundle Identifier: 系统自动生成 `com.lusansui.MoneyMap.MoneyMapWidget`
   - Language: Swift
   - **取消勾选** "Include Configuration Intent"(我们不用配置)
   - **取消勾选** "Include Live Activity"
5. 点 **Finish**
6. Xcode 会询问 "Activate scheme",点 **Activate**

### 2. 替换 Xcode 自动生成的 Widget 文件

Xcode 会在左侧文件树创建一个 `MoneyMapWidget` 文件夹,里面有 `MoneyMapWidget.swift` 和 `MoneyMapWidgetBundle.swift`。

**用我已经写好的代码替换它们**:
- 把 `MoneyMap/MoneyMapWidget/MoneyMapWidget.swift` 的内容**全部覆盖**到 Xcode 生成的同名文件
- 把 `MoneyMap/MoneyMapWidget/MoneyMapWidgetBundle.swift` 的内容**全部覆盖**到 Xcode 生成的同名文件

(我已经把这两个文件放在 `MoneyMap/MoneyMapWidget/` 目录里,你可以直接复制粘贴。)

### 3. 给主 App + Widget 都加上 App Group capability

这一步让两个 target 能共享数据:

**主 App 这边**:
1. 左侧点 **MoneyMap** project → 选中 **MoneyMap target**(主 App)
2. 顶部 tab **Signing & Capabilities**
3. 左上角点 **+ Capability** → 双击 **App Groups**
4. 在 App Groups 区域点 **+** → 输入 `group.com.lusansui.MoneyMap` → 回车
5. 勾选这一行

**Widget 这边**:
1. 切换到 **MoneyMapWidgetExtension target**
2. 同样 **Signing & Capabilities** → **+ Capability** → **App Groups**
3. 勾选刚才创建的 `group.com.lusansui.MoneyMap`

> ⚠️ 这个 ID 必须和 `WidgetState.swift` 里的 `appGroupID` 完全一致。我已经设成 `group.com.lusansui.MoneyMap`。

### 4. 编译 + 运行

按 **⌘R**。App 启动后会:
1. 主 App 拉行情数据
2. 把总资产 / 今日盈亏 写到 App Group 的 UserDefaults
3. Widget 从同一个 UserDefaults 读取并显示

### 5. 把 Widget 添加到主屏

1. 长按主屏空白区域 → 进入编辑模式
2. 左上角 **+** → 搜索 "钱袋"
3. 选择 Small 或 Medium 尺寸 → **添加小组件**

---

## 故障排查

- **Widget 显示 ¥-**:说明主 App 还没写过数据。打开主 App 跑一次,数据会自动写入。
- **Widget 不刷新**:iOS 限制 Widget 刷新频率,大约每 15-30 分钟一次。打开主 App 会强制刷新。
- **打开 Widget 就闪退**:99% 是 App Group ID 不一致。检查两个 target 的 capability + `WidgetState.swift` 里的字符串。
- **Widget 列表里搜不到「钱袋」**:重启 iPhone / 模拟器,或者删除主 App 重装。

---

如果你不想自己折腾这一步,告诉我,下一轮我把这部分挪到下一轮做,先打磨别的功能。
