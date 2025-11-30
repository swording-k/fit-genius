## 问题简述
- 报错说明同一个输出被两个构建步骤生成（常见是 `Info.plist` 或某图片/资源被同时“处理”和“复制到包资源”）。你删除 `Info.plist` 的重复后，Xcode开始提示下一个重复对象（图片），属于同类问题。我们按顺序把所有重复项清掉就能编译。

## 具体操作（严格按步骤）
1) 展开错误查看冲突对象
- 打开左侧“报告导航器”（⌘+8）或编译错误面板，点击红色条目“Multiple commands produce …”。
- 记下它显示的具体文件名（例如 `.../image/1764480...png` 或 `Assets.xcassets/...`、`Info.plist`）。这就是要清理的重复对象。

2) 清理 Copy Bundle Resources 的重复资源
- Targets → FitGenius → Build Phases → 找到“Copy Bundle Resources”。
- 在这列表里：
  - 删除任何 `Info.plist` 条目（它不应该被复制）。
  - 搜索并删除刚才错误里的具体文件名（例如那张 png）。如果该图片已经在 `Assets.xcassets`，保留 `Assets.xcassets`，删除单独文件条目；如果不是在 `Assets.xcassets`，只保留一处来源，删除重复处。
  - 留意是否有同名图片在两个不同目录都被勾选了 Target，删除其中一个。

3) 检查 Compile Sources 的重复源码
- 继续在 Build Phases → “Compile Sources”：确保每个 `.swift` 文件只出现一次；看到重复条目就删除多余的。

4) 校验 Info.plist 路径
- Targets → Build Settings → 搜索 `Info.plist File`，确保只指向一个真实路径（例如 `FitGenius/Info.plist`）。若为空或有两个候选，改成唯一的正确路径。

5) 清理缓存后重试
- Product → Clean Build Folder（⇧⌘K）。
- Xcode → Settings/Preferences → Locations → 打开 Derived Data 文件夹，删除 `FitGenius-*` 目录。
- 重新编译；如果再出现类似报错，重复第 1–2 步，按新提示的对象继续清理，直到无重复。

## 识别要删哪一个的快速规则
- 资源已在 `Assets.xcassets`：只保留 `Assets.xcassets`，删除单独复制条目。
- 非 assets 的单文件资源：确保只保留一个来源，删除重复勾选。
- `.plist`：从“Copy Bundle Resources”删除，保留在 Build Settings 的路径即可。

## 我这边的配合与下一步
- 你不需要理解所有细节，只需按上面的点击位置逐个删重复项即可；如果某个具体文件名不确定删哪一个，发我那个完整文件名，我告诉你保留/删除哪个。
- 清理完成后，项目可以不启用 Sign In with Apple 就编译运行，先测试“饮食模式”的录入与文本分析；待订阅生效再配置登录与 CloudKit。
