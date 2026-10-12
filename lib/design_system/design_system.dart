/// 软糖果冻风设计系统（shadcn 哲学：源码进项目、完全可控、行为与样式分离）
///
/// 仅依赖 `package:flutter/widgets.dart`，零第三方包、零 Material 组件。
/// - `AppTheme.of(context)` 读取全部设计令牌
/// - 组件一律无硬编码颜色/圆角/间距
/// - 交互浮层（Select/Tooltip）在根 Overlay 展示时自动重建主题继承树
library;

// 令牌
export 'tokens/colors.dart';
export 'tokens/radii.dart';
export 'tokens/shadows.dart';
export 'tokens/sketch.dart';
export 'tokens/spacing.dart';
export 'tokens/typography.dart';

// 主题
export 'theme/app_theme.dart';

// 行为原语
export 'primitives/pressable.dart';

// 组件
export 'components/accordion.dart';
export 'components/avatar.dart';
export 'components/badge.dart';
export 'components/bottom_sheet.dart';
export 'components/button.dart';
export 'components/card.dart';
export 'components/checkbox.dart';
export 'components/chips.dart';
export 'components/combobox.dart';
export 'components/date_picker.dart';
export 'components/dialog.dart';
export 'components/empty_state.dart';
export 'components/icons.dart';
export 'components/input.dart';
export 'components/jelly_box.dart';
export 'components/list_item.dart';
export 'components/list_item_card.dart';
export 'components/loading.dart';
export 'components/navigation_bar.dart';
export 'components/page_indicator.dart';
export 'components/popover.dart';
export 'components/radio.dart';
export 'components/rating.dart';
export 'components/segmented_control.dart';
export 'components/select.dart';
export 'components/skeleton.dart';
export 'components/slider.dart';
export 'components/stepper.dart';
export 'components/switch.dart';
export 'components/tabs.dart';
export 'components/toast.dart';
export 'components/top_bar.dart';
export 'components/tooltip.dart';
export 'components/progress.dart';
