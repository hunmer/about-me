# 默认 WebP 精灵图宠物资源包

来源为 https://github.com/PC2005-cloud/dsh-pet ，WebM 固定提交 `b78e3fcf92ac78cee569aed7cc27eeb2a8d51757`。分类和中文动作名称保留上游配置。

素材禁止商用；二创在公开渠道须署名原仓库。上游原始声明见 `SOURCE-upstream.txt`。`LICENSE-code.txt` 和 `LICENSE-assets.txt` 是原样保存的上游代码 MIT 许可，不覆盖素材限制。

## 资源规格

- 106 个动作，每动作一张静态有损 WebP 精灵图及同名 JSON，透明背景保留。图片总量 105,230,520 字节（100.356 MiB），单张范围 980,176–999,578 字节。
- 保留源尺寸 640×360，恢复 12 fps。105 个动作实际 120 帧，“工作状态-垂头叹气冒汗”实际 59 帧，帧数由 FFmpeg 实际采样输出计数。
- 使用 8 列；120 帧为 8×15、5120×5400，59 帧为 8×8、5120×2880。末尾空格透明，不参与播放。
- 每张图片严格小于 1,000,000 字节。逐张搜索颜色质量，并按需要量化透明边缘；不通过降低帧尺寸或删帧达标。各动作 `EncodingQuality`、`AlphaQuality` 和实际 `EncodedBytes` 记录在同名 JSON 中。
- WebP 压缩减少存储体积，不减少解码后的像素内存。最大纹理 RGBA 像素数据为 110,592,000 字节（105.469 MiB），实际内存还包括文件字节、解码临时数据、GPU 副本及切换时的新旧图片。最大纹理超过 4096，低纹理上限设备需实机验证。
- 本地保留 106 个 WebM 转换输入，共 54,351,332 字节；该目录已加入根 `.gitignore`，不打包进 Flutter assets。MOV 已删除。
- `checksums.json` 记录 318 个资源的字节数及 SHA-256：106 个 WebM、106 个 WebP、106 个动作 JSON。

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

要求 PowerShell 7、FFmpeg/ffprobe、官方 libwebp 的 `cwebp` 及本地 WebM 输入。FFmpeg 用 `libvpx-vp9` 解码以保留 Alpha；临时 PNG 网格仅在转换目录中存在，最终只打包 WebP。

```powershell
# 工具路径可通过 -Ffmpeg、-Ffprobe、-Cwebp 指定
pwsh -NoProfile -File "scripts/convert_video_pet_spritesheet.ps1" -All

# 中断后复用已完成且参数、体积一致的动作
pwsh -NoProfile -File "scripts/convert_video_pet_spritesheet.ps1" -All -Resume

# 单个动作
pwsh -NoProfile -File "scripts/convert_video_pet_spritesheet.ps1" -Action "东张西望"
```

脚本读取 fps 过滤后的实际帧数，不根据视频时长估算。每张编码后校验尺寸、透明格式及实际字节数，再更新元数据；全量转换成功后更新 manifest、移除被替代的生成 PNG 并重算校验和。`-MaxBytes` 默认 1000000，采用严格小于判断。

颜色质量通过整数二分搜索；透明边缘从质量 50 开始，必要时逐级降至 25、10、1，优先为颜色细节保留空间。透明度量化会改变半透明边缘，不保证逐像素无损；无透明像素仍保持透明。
