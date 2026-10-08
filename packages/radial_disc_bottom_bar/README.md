# radial_disc_bottom_bar

双层同心圆弧浮动底部导航栏（Radial Disc Bottom Bar）。

主层为一条弧形扇环 dock，tab 沿圆弧排布并按切线方向旋转，选中项药丸以弹簧物理沿弧线滑动；
上层为可折叠子栏：左右两个圆按钮 + 中间双选项分段（弧形药丸沿弧线滑动）。

- 右端停靠：`dockedAction` 在 dock 右端帽停靠一个自带手势的小操作钮（如“添加”），tab 角度自动收窄避让
- 磨砂玻璃：`frosted: true` 时扇环用 ClipPath + BackdropFilter 做背景模糊（阴影层在玻璃外绘制，投影不被切断）

## 几何

画布 380×146，曲率圆心位于画布下方 (190, 636)：

- 主 dock：半径 526~580 的扇环（±16.2°），tab 均布在 ±13.5°
- 上层子栏：半径 588~624 的扇环（±10.8°），圆按钮在 ±15.4°，选项在 ±5.4°
- 滑动药丸：56×42（主层）/ 弧形扇环（子层），弹簧 stiffness 420 / damping 34

仅使用主 dock（子栏无内容或 `never`）时固有尺寸为 380×78（自动裁掉上下空区，贴合底部布局）。

## 使用

```dart
RadialDiscBottomBar(
  tabs: [
    RadialDiscTab(
      label: 'Home',
      iconBuilder: (_, selected) => Icon(
        Icons.home,
        color: selected ? Colors.white : Colors.grey,
      ),
    ),
    // ... 更多 tab
  ],
  activeIndex: 0,
  onTabChange: (i) => setState(() => index = i),
  // 上层子栏（可选）
  subBarBehavior: RadialSubBarBehavior.auto,
  subLabels: ('Option A', 'Option B'),
  subOption: RadialSubOption.left,
  onSubOptionChange: (opt) => setState(() => subOption = opt),
  leadingAction: const Icon(Icons.sports_esports),
  onLeadingTap: () {},
  trailingAction: const Icon(Icons.visibility),
  onTrailingTap: () {},
  style: RadialDiscBarStyle.fromBrightness(isDark),
)
```

- 更窄的容器中用 `FittedBox(fit: BoxFit.scaleDown)` 等比缩放
- `RadialSubBarBehavior.auto`：前半部分 tab 展示子栏，切到后半部分自动收起
- tab 数量可变（≥1），角度在 ±13.5° 内均分
