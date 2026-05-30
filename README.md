# DMS Claude Pet

一个用于 [Dank Material Shell](https://github.com/AvengeMedia/DankMaterialShell) 的 **状态感知桌面宠物插件**，栖息在 DankBar 中，通过动画实时反映 [Claude Code](https://claude.com/code) 的工作状态。

## 预览

| 状态 | 效果 | 触发条件 |
|------|------|---------|
| 😌 idle | 呼吸起伏 + 眨眼 + 偶尔小跳 | Claude 等待输入 |
| ⚡ working | 15° 左右摆动 | Claude 调用工具、执行代码 |
| ☀️ waking | 伸懒腰弹跳 | 新会话开始 |
| 💤 sleeping | 闭眼 + 变暗 + 慢呼吸 | 会话结束 |
| 😵 error | 变红 + 摇头 + 红色瞳孔 | 工具执行失败 |
| 🚨 alert | 跳跃 + 红色大嘴 | 需要用户授权 |

## 架构

```
Claude Code (CLI / VSCode)
  │  Hook 事件: SessionStart, PreToolUse, PostToolUse, Stop...
  ▼
update-claude-state.sh  ──→  ~/.cache/dms-pet/claude-state.json
                                    │
                              QML Timer 轮询 (800ms)
                                    │
                             PetBlob 切换动画
```

无论从终端 (`claude`) 还是 VSCode 扩展调用 Claude Code，hooks 都会触发。Claude Code hooks 是引擎层功能，与 UI 无关。

## 文件结构

```
dmsPet/
├── plugin.json                    # DMS 插件清单
├── DmsPet.qml                     # 主组件：PluginComponent + PetBlob + 状态轮询
├── PetSettings.qml                # 设置面板
└── scripts/
    └── update-claude-state.sh     # Claude Code hook 桥接脚本
```

## 安装

### 1. 部署插件

```bash
cp -r dmsPet ~/.config/DankMaterialShell/plugins/
```

### 2. 启用插件

```bash
# 在 DMS 设置中：
# Settings → Plugins → 找到 "Claude Pet" → 启用

# 或通过 CLI：
cat ~/.config/DankMaterialShell/plugin_settings.json | \
  jq '.dmsPet = {"enabled": true}' > /tmp/ps.json && \
  mv /tmp/ps.json ~/.config/DankMaterialShell/plugin_settings.json
```

### 3. 添加到 DankBar

在 DMS 设置中将 `dmsPet` 添加到 Bar 的 widget 列表中。

或者编辑 `~/.config/DankMaterialShell/settings.json`，在 `barConfigs[0].centerWidgets` 中添加：

```json
{ "id": "dmsPet", "enabled": true }
```

### 4. 配置 Claude Code Hooks

在 `~/.claude/settings.json` 中为以下事件添加 hook：

```
SessionStart, PreToolUse, PostToolUse, PostToolUseFailure,
Stop, StopFailure, Notification, SessionEnd
```

每个事件添加：

```json
{
  "matcher": "",
  "hooks": [{
    "type": "command",
    "command": "~/.config/DankMaterialShell/plugins/dmsPet/scripts/update-claude-state.sh",
    "timeout": 5
  }]
}
```

### 5. 重启 DMS

```bash
dms restart
```

## 设置

| 设置 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| Pet Name | 字符串 | "Clawdy" | 宠物名字 |
| Pet Size | 滑块 (50%-150%) | 100% | 在 DankBar 中的大小 |
| Animation Speed | 滑块 (50%-200%) | 100% | 动画播放速度 |
| Use Theme Color | 开关 | on | 使用 Material You 主题色 |
| Custom Pet Color | 颜色 | #7C9CBF | 自定义颜色（关闭主题色时生效） |
| Show State Emoji | 开关 | off | 头顶显示状态 emoji |

## 技术细节

- **纯 QML 矢量绘制** — 无需外部图片资源，用 Rectangle + radius 绘制 blob
- **Transform 动画** — 使用 `Translate` + `Rotation` transform 而非直接 x/y/rotation，避免与 anchors 布局冲突
- **状态轮询** — `Quickshell.Io.Process` 每 800ms 读取状态文件
- **失效保护** — 状态文件超过 30s 未更新自动回退到 idle
- **单文件内联组件** — 使用 QML `component` 关键字将 PetBlob 内联在 DmsPet.qml 中，避免跨文件加载问题

## 依赖

- DMS ≥ 1.4.0
- Quickshell ≥ 0.3.0
- jq（hook 脚本需要）
- Claude Code（任意调用方式：CLI / VSCode 扩展）

## 相关资源

- [DMS 插件开发文档](https://danklinux.com/docs/dankmaterialshell/plugin-development)
- [Claude Code Hooks 文档](https://code.claude.com/docs/en/hooks)
- [DMS 源码](https://github.com/AvengeMedia/DankMaterialShell)

## License

MIT
