# Flotsam 相机 / 视野 / 地图切换优化

## 背景

Flotsam 的相机视野范围较窄、缩放偏慢，缩放到极限后切换到世界地图/主场景还要等待数秒，地图打开时的默认距离也偏远。本工具通过修改游戏场景文件 `level2` 中的相机参数解决这些问题，所有数值集中在 `config.json`，可自由调整并可随时恢复原版。

适用版本：Flotsam `1.0.1f9`（Epic / Steam，Unity `6000.3.26f1`，Mono）。

---

## ✅ TL;DR：一键脚本（推荐）

默认的 `config.json` 已经是一套调整好的推荐数值，下载后直接运行即可。

| 步骤 | 操作 |
| --- | --- |
| 1 | 点击本页右上角 **Code → Download ZIP**，解压到任意文件夹（不要解压到游戏目录里） |
| 2 | **完全退出** Flotsam（包括 Epic 启动器里的游戏进程） |
| 3 | 如果你只想用推荐值，跳过此步；想自定义则用记事本编辑 `config.json`（见下方参数表） |
| 4 | 双击 **`Apply-Camera-Tweaks.bat`**，等待窗口显示“修改完成” |
| 5 | 启动游戏即可生效 |
| 6 | 想恢复原版：双击 **`Restore-Camera-Tweaks.bat`** |

> 游戏安装在 `Program Files` 等受保护目录时，请右键 `Apply-Camera-Tweaks.bat` → **以管理员身份运行**。
>
> 首次运行会自动把原版 `level2` 备份到 `backup\`，恢复脚本依赖这个备份，请不要删除。

### 可调参数

`config.json` 中所有数值都可以改；写成小数（如 `180.0`）即可。

| 参数 | 原厂值 | 推荐值 | 说明 |
| --- | --- | --- | --- |
| `main_camera.pitch_min_degrees` | 27.5 | 12 | 主相机俯仰角下限（更小 = 视角更接近水平，看得更远） |
| `main_camera.pitch_max_degrees` | 61.25 | 78 | 主相机俯仰角上限（更大 = 更接近俯视） |
| `main_camera.zoom_min_distance` | 15 | 15 | 主相机最近缩放距离 |
| `main_camera.zoom_max_distance_mouse` | 130 | 180 | 主相机鼠标最远缩放距离（越大视野越广） |
| `main_camera.zoom_max_distance_joystick` | 100 | 180 | 主相机手柄最远缩放距离 |
| `main_camera.zoom_speed_mouse` | 7.5 | 13.65 | 主相机鼠标缩放速度（越大越快） |
| `main_camera.zoom_speed_joystick` | 1.0 | 1.82 | 主相机手柄缩放速度 |
| `main_camera.switch_wait_seconds` | 0.75 | 0.2 | 主相机拉到极限后，等待多久切换到地图（秒） |
| `main_camera.pan_speed` | 200 | 200 | 主相机平移速度 |
| `main_camera.rotate_step_degrees` | 8.75 | 8.75 | 每次旋转操作的角度步长 |
| `main_camera.rotate_smoothness` | 0.75 | 0.75 | 旋转平滑度（0–1） |
| `map_camera.zoom_min_distance` | 500 | 800 | 地图相机最近缩放距离 |
| `map_camera.zoom_max_distance` | 1500 | 2600 | 地图相机最远缩放距离 |
| `map_camera.default_zoom` | 0.3 | 0.0001 | 打开地图时的默认缩放：`0` = 最近距离，`1` = 最远距离 |
| `map_camera.zoom_speed_mouse` | 10 | 7.5 | 地图相机鼠标缩放速度 |
| `map_camera.zoom_speed_joystick` | 5 | 3.75 | 地图相机手柄缩放速度 |
| `map_camera.switch_wait_seconds` | 1.0 | 0.2 | 地图相机拉到极限后，等待多久切回主场景（秒） |
| `map_camera.fade_seconds` | 0.5 | 0.2 | 地图打开/关闭的淡入淡出时长（秒） |
| `map_camera.pan_speed_min` / `pan_speed_max` | 200 / 1000 | 200 / 1000 | 地图相机平移速度范围 |
| `game_dir` | 空 | 空 | 留空会自动查找游戏目录；查找失败时填写游戏根目录（含 `Flotsam.exe`） |

> `switch_wait_seconds` 对应游戏的 `Easing` 字段，它同时影响缩放的平滑插值：值越小，切换越快、缩放越“直接”。

---

## 其他方案

### 方案 B：手动修改（适合想自己写工具或只改一两个值的人）

游戏把相机参数序列化在 `Flotsam_Data\level2`（Unity SerializedFile）里，对应三个组件：

| 组件 | 内容 |
| --- | --- |
| `CameraController`（主相机） | 平移速度、旋转步长/平滑度、俯仰角上下限 |
| `CameraZoomController`（主相机，34027） | 缩放距离范围、缩放速度、切换等待（Easing） |
| `CameraZoomController`（地图相机，34352） | 地图缩放距离范围、默认缩放、缩放速度、切换等待 |
| `WorldMap`（28728） | 地图打开/关闭淡入淡出时长 |

可以用 UnityPy、AssetStudio 等工具读取这些字段后修改，或参考 `tools\apply.ps1` 中的“原始数值 → 新数值”字节替换逻辑，自己实现一份。

### 方案 C：仅调整某一项

修改 `config.json` 中对应字段后重新运行 `Apply-Camera-Tweaks.bat` 即可（不需要先恢复原版，脚本会以首次备份的原版文件为基准重新生成）。

---

## 注意事项

| 事项 | 说明 |
| --- | --- |
| 游戏版本 | 仅针对 Flotsam `1.0.1f9`（Unity `6000.3.26f1`）验证；版本不一致时脚本会报“找不到原始数据”，不会写入文件 |
| 备份 | 首次运行自动生成 `backup\level2.original`，恢复原版依赖它，请勿删除 |
| Epic 验证文件完整性 / 游戏更新 | 会把 `level2` 还原为原版，需要重新运行 `Apply-Camera-Tweaks.bat`；更新后若提示找不到原始数据，请先删除 `backup\` 再运行 |
| 与“设置重置修复”共存 | 本工具只修改 `level2`，不修改游戏 DLL，可与 [flotsam-epic-settings-fix](https://github.com/MineMahiro/flotsam-epic-settings-fix) 同时使用 |
| 权限 | 游戏位于 `Program Files` 时需以管理员身份运行 |
| 风险 | 属于非官方修改，请自行承担风险；建议先备份存档 |

---

## 验证方法

| 检查项 | 方法 |
| --- | --- |
| 视野范围 | 游戏中把主相机滚轮拉到最远，能看到的范围应明显大于原版 |
| 切换延迟 | 保持拉到最远约 0.2 秒，应自动切换到地图；地图里拉到最近约 0.2 秒，应切回主场景 |
| 地图默认距离 | 打开地图时，视角应处于地图最拉近的状态（距离约 800） |
| 缩放速度 | 主相机滚轮缩放明显更快；地图相机缩放比原版稍慢 |
| 恢复原版 | 运行 `Restore-Camera-Tweaks.bat` 后与原版一致 |

---

## 原理

- 相机参数不是代码常量，而是序列化在 `Flotsam_Data\level2`（Unity SerializedFile）中的组件字段，因此可以直接修改数据而不改动游戏 DLL。
- 地图与主场景的切换逻辑：`CameraZoomController` 在缩放到达极限后等待 `_zoomTimer`（初值来自场景里的 `Easing` 字段）→ 派发 `CameraMaximumZoom` / `CameraMinimumZoom` 事件 → `WorldMapManager` 收到后调用 `WorldMap.Open()` / `Close()` → 淡入淡出切换。
- `tools\apply.ps1` 用“原版数值序列”在文件中唯一定位每个字段（如 `0.75, 8.75, 200, 27.5, 61.25`），只替换这些浮点数对应的字节，文件大小和序列化结构保持不变；首次运行会把原版文件备份到 `backup\`，恢复时直接还原备份。

## 兼容性

| 项目 | 值 |
| --- | --- |
| 测试版本 | Flotsam `1.0.1f9`（Epic / Steam，Unity `6000.3.26f1`，Mono） |
| 原始 `level2` SHA256 | `8A79413A6E6754526256FC283A190BC56C8184F39968AB56D21BAB5275D486D1` |
| 生成后哈希 | 每次应用后脚本会显示当前 `level2` 的 SHA256 |
| 定位方式 | 按原版数值序列唯一匹配，不做版本号判断 |

## 常见问题

Q1: **修改后需要重开存档吗？**  
A1: 不需要，完全退出游戏再启动即可；修改的是场景文件，不涉及存档数据。

Q2: **游戏更新后失效怎么办？**  
A2: 先删除 `backup\` 文件夹，再重新运行 `Apply-Camera-Tweaks.bat`；也可以先用 Epic 的「验证文件完整性」恢复原版。

Q3: **会影响成就或联机吗？**  
A3: 只修改本地相机参数，不写入存档；未在其他平台或联机场景验证。

Q4: **运行脚本提示找不到游戏目录（如 `Drive ... does not exist`）？**  
A4: 脚本会自动查找 Epic 清单、Steam 库和所有磁盘的常见安装目录；如果全部未找到，会直接提示输入游戏根目录（包含 `Flotsam.exe` 的文件夹），输入成功后会记住到 `config.json` 的 `game_dir`。也可以提前在 `config.json` 中手动填写，例如 `"game_dir": "D:\\Games\\Flotsam"`。

## 免责声明

- 本仓库不包含任何游戏本体文件或闭源产物，仅提供脚本、配置与文档。
- 仅用于解决相机视野、缩放速度与地图切换体验问题。
- 与游戏开发商、发行平台无任何关联。
- 如官方后续版本已修复或调整相关行为，请优先使用官方版本。

## 目录结构

```
flotsam-camera-tweaks/
├─ Apply-Camera-Tweaks.bat      # 应用修改
├─ Restore-Camera-Tweaks.bat    # 恢复原版
├─ config.json                  # 可调参数（默认推荐值）
├─ presets/vanilla.json         # 原厂数值参考
├─ tools/apply.ps1              # 修改脚本
├─ tools/restore.ps1            # 恢复脚本
└─ README.md / README.en.md
```

## License

MIT
