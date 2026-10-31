# 默认 WebP 精灵图宠物资源包

来源为 https://github.com/PC2005-cloud/dsh-pet ，WebM 固定提交 `b78e3fcf92ac78cee569aed7cc27eeb2a8d51757`。分类和中文动作名称保留上游配置。

素材禁止商用；二创在公开渠道须署名原仓库。上游原始声明见 `SOURCE-upstream.txt`。`LICENSE-code.txt` 和 `LICENSE-assets.txt` 是原样保存的上游代码 MIT 许可，不覆盖素材限制。

## 资源规格

- 108 个动作，每动作一张静态有损 WebP 精灵图及同名 JSON，透明背景保留。图片总量 113,194,550 字节（107.99 MiB），单张范围 980,176–3,988,408 字节。
- 保留源尺寸 640×360，恢复 12 fps。105 个动作实际 120 帧，“工作状态-垂头叹气冒汗”实际 59 帧，“工作加班”与“熬夜刷手机”各 360 帧，帧数由 FFmpeg 实际采样输出计数。
- 使用 8 列；120 帧为 8×15、5120×5400，59 帧为 8×8、5120×2880，360 帧为 8×45、5120×16200。末尾空格透明，不参与播放。
- 106 个上游动作每张图片严格小于 1,000,000 字节。“工作加班”与“熬夜刷手机”为 ProRes 4444 透明源重制版，按用户放宽的上限每张小于 4,000,000 字节（实际 3,975,622 / 3,988,408 字节，颜色质量 50/64，远高于旧版），不通过降低帧尺寸或删帧达标。各动作 `EncodingQuality`、`AlphaQuality` 和实际 `EncodedBytes` 记录在同名 JSON 中。
- WebP 压缩减少存储体积，不减少解码后的像素内存。最大纹理 RGBA 像素数据为 331,776,000 字节（316.86 MiB，5120×16200），实际内存还包括文件字节、解码临时数据、GPU 副本及切换时的新旧图片。最大纹理超过 4096，低纹理上限设备需实机验证。
- “工作加班”与“熬夜刷手机”各带一条 AAC 音轨 `audio/<动作>.m4a`（约 740 KB，30 秒）。透明 MOV 源本身无音轨，音轨提取自同一表演的旧导出版（json `AudioNote` 如实记录）。`pubspec.yaml` 已包含 `assets/live2d/video/dsh_pet/audio/` 目录声明。
- 本地保留 106 个 WebM 及 2 个透明 ProRes 4444 MOV 转换输入，合计 1,428,049,896 字节（约 1.43 GB）：WebM 共 54,351,332 字节，MOV 共 1,373,698,564 字节（694,701,013 + 678,997,551）。该目录已加入根 `.gitignore`，不打包进 Flutter assets。
- `checksums.json` 记录 326 个资源的字节数及 SHA-256：106 个 WebM、2 个 MOV、108 个 WebP、108 个动作 JSON、2 个 M4A。

## manifest 和兼容

`manifest.json` 保留原有包 ID、名称、640×360 逻辑画布、动作 ID/名称/分类、待机、悬浮、点击及区域绑定。

```json
{
  "sources": {"webp": "spritesheet/东张西望.webp"},
  "spritesheet": {
    "frameWidth": 640,
    "frameHeight": 360,
    "columns": 8,
    "rows": 15,
    "frameCount": 120,
    "fps": 12
  }
}
```

运行时和导入支持静态 WebP、PNG。每个动作只允许一个图片来源，并同时提供 `spritesheet`。已有档案使用默认内置 assets 时，播放前按动作 ID 刷新图片来源和网格参数，保留用户配置的动作名称、区域和绑定；独立保存或导入的 PNG 包继续使用自己的资源和参数。

## 重新生成

要求 PowerShell 7、FFmpeg/ffprobe、官方 libwebp 的 `cwebp` 及本地转换输入。FFmpeg 用 `libvpx-vp9` 解码 WebM 以保留 Alpha，MOV/MP4 由 FFmpeg 自动选择解码器（ProRes 4444 的 `yuva444p12le` Alpha 由此保留）；临时 PNG 网格仅在转换目录中存在，最终只打包 WebP。

```powershell
# 工具路径可通过 -Ffmpeg、-Ffprobe、-Cwebp 指定
pwsh -NoProfile -File "scripts/convert_video_pet_spritesheet.ps1" -All

# 中断后复用已完成且参数、体积一致的动作
pwsh -NoProfile -File "scripts/convert_video_pet_spritesheet.ps1" -All -Resume

# 单个动作
pwsh -NoProfile -File "scripts/convert_video_pet_spritesheet.ps1" -Action "东张西望"

# 新增透明重制版动作（4 MB 上限由用户放宽；源同名 .mp4 > .webm > .mov 优先，新导出可复现地遮蔽旧源）
pwsh -NoProfile -File "scripts/convert_video_pet_spritesheet.ps1" -Action "工作加班" -MaxBytes 4000000
```

脚本读取 fps 过滤后的实际帧数，不根据视频时长估算。每张编码后校验尺寸、透明格式及实际字节数，再更新元数据；全量转换成功后更新 manifest、移除被替代的生成 PNG 并重算校验和。`-MaxBytes` 默认 1000000，采用严格小于判断。

颜色质量通过整数二分搜索；透明边缘从质量 50 开始，必要时逐级降至 25、10、1，优先为颜色细节保留空间。透明度量化会改变半透明边缘，不保证逐像素无损；无透明像素仍保持透明。
