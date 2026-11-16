# RazerMonWidget

[English](README.md) | 简体中文

将雷蛇鼠标、键盘的电量显示在 macOS 系统「电池」Widget 中，无需菜单栏应用。

**本项目的核心逻辑来自 [ab4317/RazerMon](https://github.com/ab4317/RazerMon)。** HID 设备发现、HyperSpeed 电量协议、序列号识别、电量换算和设备目录均迁移自 RazerMon。感谢原项目作者与贡献者的工作。

RazerMonWidget 在这些核心逻辑之上，使用 atkctl 的 IOKit 电源发布方式，并提供由 launchctl 管理的用户后台服务。

需要 macOS 13+，支持 Apple Silicon 和 Intel。普通用户无需 Swift、Xcode、克隆仓库或编译。设备目录中的候选型号不代表每个型号均经过硬件验证，兼容范围与 RazerMon 相同。

## 安装和启动

从 GitHub Release 下载预编译产物并安装：

```sh
curl -fsSL https://raw.githubusercontent.com/xiehuc/RazerMonWidget/main/install.sh | bash

# 指定版本
curl -fsSL https://raw.githubusercontent.com/xiehuc/RazerMonWidget/main/install.sh | bash -s -- --version v1.0.0
```

默认仓库为 `xiehuc/RazerMonWidget`；fork 可以传 `--repo OWNER/REPO` 或设置 `RAZERMONWIDGET_REPO`。发布前需确保该仓库与实际 GitHub 地址一致。安装器验证 SHA-256 和可执行文件签名后，再调用程序安装服务。

本地开发测试，先自行编译，再通过单独的 flag 安装已有产物：

```sh
swift build -c release
bash install.sh --local
```

`--local` 无需路径参数，依次查找项目下 `.build/release/RazerMonWidget`、`.build/apple/Products/Release/RazerMonWidget`、`dist/RazerMonWidget-macos-universal`，不下载、不编译，保留二进制原有签名；本地未签名产物需先执行 `codesign --force --sign - --identifier local.razermonwidget.battery /path/to/RazerMonWidget`。`scripts/install.sh` 转发相同参数到根目录安装器。

程序安装为当前登录用户的 LaunchAgent。不要使用 sudo。安装后立即启动，登录后自动运行，由 launchctl 保活。

安装位置：

- 程序：`~/.local/bin/RazerMonWidget`
- 配置：`~/Library/LaunchAgents/local.razermonwidget.battery.plist`
- 日志：`~/Library/Logs/RazerMonWidget-battery.log`

在「系统设置 → 隐私与安全性 → 输入监控」中添加**安装位置的程序**并启用权限，再重启：

```sh
launchctl kickstart -k gui/$(id -u)/local.razermonwidget.battery
```

接收器包含键盘类 HID 接口，因此可能需要输入监控权限。程序只读取厂商协议的设备信息和电量，不监听键盘输入。更新 ad-hoc 签名程序后，如权限失效，请删除原权限记录并重新添加安装路径。

在桌面或通知中心添加系统「电池」Widget，唤醒设备后查看日志中的百分比。launchctl 启动成功本身不代表 HID 权限或 Widget 发布成功。

## 使用和维护

```sh
# 前台运行（先停止后台服务，避免并发访问 HID）
launchctl bootout gui/$(id -u)/local.razermonwidget.battery
swift run RazerMonWidget

# 重新加载已安装的服务
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.razermonwidget.battery.plist

# 查看服务状态和日志
launchctl print gui/$(id -u)/local.razermonwidget.battery
tail -f ~/Library/Logs/RazerMonWidget-battery.log

# 卸载，保留日志
"$HOME/.local/bin/RazerMonWidget" --uninstall-service

# 测试
swift test
```

每 60 秒刷新电量，失败后约 5 秒重试；USB 插拔触发重新发现。每个序列号有独立的 Widget 电量条目。设备休眠或临时读取失败时保留上次电量，物理接收器拔出时删除其条目，SIGTERM/SIGINT 正常退出时释放全部条目。不要同时运行 RazerMon 或其他访问相同接收器的工具。

电量由 0–255 原始值换算为 0–100%。现有 RazerMon 协议没有读取充电状态，因此不显示充电标志。发送使用运行时解析的私有 IOKit API；系统升级可能改变接口或 Widget 行为，接口不存在时程序会明确报错。无需修改系统 Widget 或安装 Widget 扩展。

设备目录已嵌入可执行程序，安装不依赖源码目录或 SwiftPM 资源路径。安装后的稳定副本不受清理构建目录影响。

## 来源

- **[RazerMon](https://github.com/ab4317/RazerMon)**：本项目核心逻辑的来源，包括 HID 发现、HyperSpeed 电量协议、序列号识别、电量换算与设备目录。保留原项目的 MIT 许可证，见 [LICENSE.RazerMon](LICENSE.RazerMon)。
- atkctl：电源发布和 LaunchAgent 管理逻辑，见 [LICENSE.atkctl](LICENSE.atkctl)。

## GitHub Release 发布

维护者运行 `bash scripts/build-release.sh` 可生成 Apple Silicon + Intel 通用可执行文件和 SHA-256 文件：

- `dist/RazerMonWidget-macos-universal`
- `dist/RazerMonWidget-macos-universal.sha256`

推送 `v*` 标签后，`.github/workflows/release.yml` 会测试、编译两个架构、ad-hoc 签名并上传以上文件到对应 GitHub Release；也可以手动运行 workflow，指定已有标签。安装脚本与 Release 产物命名保持一致。远程安装要求目标仓库已有包含上述文件的 Release。
