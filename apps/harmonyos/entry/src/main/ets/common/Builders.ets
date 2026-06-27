/**
 * 全局共享 @Builder
 * 跨页面复用的 UI 片段
 */

import { Constants } from './Constants';

/**
 * 统计卡片
 * @param value  数值文本（调用方预先计算并转为 string）
 * @param label  标签文本
 * @param color  数值颜色
 */
@Builder
export function StatCard(value: string, label: string, color: ResourceColor) {
  Column() {
    Text(value)
      .fontSize(24)
      .fontWeight(FontWeight.Bold)
      .fontColor(color)
    Text(label)
      .fontSize(12)
      .fontColor(Constants.COLOR_TEXT_SECONDARY)
      .margin({ top: 4 })
  }
  .layoutWeight(1)
  .padding(14)
  .backgroundColor(Constants.COLOR_BG_CARD)
  .borderRadius(12)
  .alignItems(HorizontalAlign.Center)
}
