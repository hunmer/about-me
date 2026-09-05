# 调查发现

## 2026-09-05

- `buildSelectField` 使用 `DSPopover`，选项列表已改为有限高度的 `Scrollbar + ListView`。
- `DSPopover` 当前固定使用 `targetAnchor: bottomCenter` 和 `followerAnchor: topCenter`，未根据视口剩余空间改变方向。
