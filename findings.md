# 调查发现

## 2026-09-05

- `buildSelectField` 使用 `DSPopover`，选项列表已改为有限高度的 `Scrollbar + ListView`。
- `DSPopover` 当前固定使用 `targetAnchor: bottomCenter` 和 `followerAnchor: topCenter`，未根据视口剩余空间改变方向。
- `DSPopover` 已改为按触发控件上下剩余空间选择方向，并限制面板最大高度。
- `DSInput` 已配置 `materialTextSelectionControls`，补齐移动端文本选择手柄和上下文菜单；桌面 Ctrl+A 与拖选测试均通过。
- `DSSelect` 与 `DSCombobox` 已有向上展开及滚动容器，本次未做无关改动。
