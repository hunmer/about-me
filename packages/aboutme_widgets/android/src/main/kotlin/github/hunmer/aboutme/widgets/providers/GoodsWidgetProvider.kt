package github.hunmer.aboutme.widgets.providers

import github.hunmer.aboutme.widgets.BasePluginWidgetProvider

/**
 * 物品管理小组件 - 1x1 尺寸
 */
class GoodsWidgetProvider : BasePluginWidgetProvider() {
    override val pluginId: String = "goods"
    override val widgetSize: WidgetSize = WidgetSize.SIZE_1X1
}

/**
 * 物品管理小组件 - 2x2 尺寸
 */
class GoodsWidget2x1Provider : BasePluginWidgetProvider() {
    override val pluginId: String = "goods"
    override val widgetSize: WidgetSize = WidgetSize.SIZE_2X2
}
