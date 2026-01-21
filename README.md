# CrateTrackerZK | 空投物资追踪器

[English](#english) | [中文](#中文)

---

## English

CrateTrackerZK is a World of Warcraft addon that tracks War Supply Crate airdrops across Khaz Algar maps, helping you quickly know when and where crates will appear.

### Features

- **Automatic Detection** - Automatically detects War Supply Crate airdrops when they appear (outdoor areas only)
- **Auto Timers & Countdowns** - Records the last refresh time and calculates the next drop, showing live countdowns for each map
- **Phasing Tracking** - Tracks phasing (instance) IDs with color indicators (Green = same phase, Red = phase changed)
- **Party/Raid Notifications** - Optional notifications to alert your group when a crate is detected (enabled by default)
- **Team Time Sharing** - Automatically synchronizes airdrop times through team chat messages (enabled by default)
- **Manual Refresh** - Manually start timers by clicking the Refresh button
- **Floating Button** - Provides a floating button to reopen the addon UI after closing it
- **Automatic Data Saving** - All data is saved automatically and persists between sessions
- **Multi-Language Support** - Supports English, Simplified Chinese, Traditional Chinese, and Russian

### Installation

1. Download the latest release from [GitHub Releases](https://github.com/capzk/CrateTrackerZK/releases)
2. Extract the zip file to your `World of Warcraft/_retail_/Interface/AddOns/` directory
3. Restart the game or use `/reload` command
4. Use `/ctk` to open the interface

### Slash Commands

- `/ctk` - Show help information
- `/ctk help` - Show help information
- `/ctk on` - Enable addon
- `/ctk off` - Disable addon (pause detection and hide UI)
- `/ctk team on` - Enable party/raid notifications
- `/ctk team off` - Disable party/raid notifications
- `/ctk clear` - Clear all saved data

### Localization & Translation

The addon supports multiple languages with comprehensive localization. For translation instructions, see our [Translation Guide](docs/TRANSLATION_GUIDE.md).

**Supported Languages:**
- English (enUS) - Default/Fallback
- 简体中文 (zhCN) - Simplified Chinese
- 繁體中文 (zhTW) - Traditional Chinese
- Русский (ruRU) - Russian

If you notice translation inaccuracies or want to contribute translations, please feel free to leave feedback or create your own local translation following our guide.

### Notes

- Automatic detection only works in valid outdoor areas
- Detection is automatically paused in capital cities, instances, battlegrounds, and indoor areas
- Team time sharing works automatically when team members have notifications enabled

---

## 中文

CrateTrackerZK 是一个魔兽世界插件，用于追踪卡兹阿加地图上的战争物资空投箱，帮助您快速了解空投箱何时何地出现。

### 功能特色

- **自动检测** - 自动检测战争物资空投箱出现（仅限户外区域）
- **自动计时和倒计时** - 记录上次刷新时间并计算下次空投时间，显示各地图的实时倒计时
- **位面追踪** - 追踪位面（实例）ID，用颜色指示器显示（绿色=相同位面，红色=位面已变更）
- **小队/团队通知** - 可选通知功能，在检测到空投箱时提醒您的队伍（默认开启）
- **团队时间共享** - 通过团队聊天消息自动同步空投时间（默认开启）
- **手动刷新** - 通过点击刷新按钮手动启动计时器
- **浮动按钮** - 提供浮动按钮以在关闭后重新打开插件界面
- **自动数据保存** - 所有数据自动保存并在会话间保持
- **多语言支持** - 支持英语、简体中文、繁体中文和俄语

### 安装方法

1. 从 [GitHub Releases](https://github.com/capzk/CrateTrackerZK/releases) 下载最新版本
2. 将压缩包解压到您的 `魔兽世界/_retail_/Interface/AddOns/` 目录
3. 重启游戏或使用 `/reload` 命令
4. 使用 `/ctk` 打开界面

### 斜杠命令

- `/ctk` - 显示帮助信息
- `/ctk help` - 显示帮助信息
- `/ctk on` - 启动插件
- `/ctk off` - 关闭插件（暂停检测并隐藏界面）
- `/ctk team on` - 开启小队/团队通知
- `/ctk team off` - 关闭小队/团队通知
- `/ctk clear` - 清除所有保存的数据

### 本地化和翻译

插件支持多语言并提供全面的本地化功能。翻译说明请参见我们的[翻译指南](docs/TRANSLATION_GUIDE.md)。

**支持的语言：**
- English (enUS) - 默认/回退语言
- 简体中文 (zhCN) - 简体中文
- 繁體中文 (zhTW) - 繁体中文
- Русский (ruRU) - 俄语

如果您发现翻译不准确或想要贡献翻译，请随时留下反馈或按照我们的指南创建您自己的本地翻译。

### 注意事项

- 自动检测仅在有效的户外区域工作
- 在主城、副本、战场和室内区域会自动暂停检测
- 当团队成员开启通知功能时，团队时间共享会自动工作

---

## License | 许可证

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

本项目采用 MIT 许可证 - 详情请参见 [LICENSE](LICENSE) 文件。
