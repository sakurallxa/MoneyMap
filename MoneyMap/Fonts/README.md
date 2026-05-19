# 字体资源

中文衬线主字使用 **Source Han Serif SC**(思源宋体)的 4 个字重。源仓不入库 OTF 文件(共 ~88 MB),需自行下载。

## 下载

官方仓:<https://github.com/adobe-fonts/source-han-serif>

需要的字重(放进当前 `MoneyMap/Fonts/` 目录,文件名必须与下方一致):

- `SourceHanSerifSC-ExtraLight.otf`
- `SourceHanSerifSC-Light.otf`
- `SourceHanSerifSC-Medium.otf`
- `SourceHanSerifSC-Regular.otf`

## 注册方式

字体在 [`MoneyMap/App/MoneyMapApp.swift`](../App/MoneyMapApp.swift) 运行时通过 `CTFontManagerRegisterFontsForURL` 动态注册,不依赖 `Info.plist UIAppFonts`。Bundle 加载时若找不到任一字体,Theme 会回落到系统宋体 / Times → SF Pro。

> ⚠️ 在 Xcode 中把这 4 个 OTF 加进 `MoneyMap` target(Build Phases → Copy Bundle Resources),否则 `Bundle.main.url(forResource:withExtension:)` 取不到。

## 许可

Source Han Serif 使用 **SIL Open Font License 1.1**(SIL OFL 1.1),可商用、可嵌入 App Bundle 内一并分发,无须付费授权。许可全文见 `OFL.txt`(随 Adobe 发布包附带)。
