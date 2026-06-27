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
  .borderRadius(Constants.RADIUS_MD)
  .shadow({ radius: 12, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 2 })
  .alignItems(HorizontalAlign.Center)
}

/**
 * 统一标题栏（带返回按钮）
 * @param title       主标题
 * @param subtitle    副标题（可选，传空字符串则不显示）
 */
@Builder
export function TitleBar(title: string, subtitle: string, onBack: () => void) {
  Row() {
    Text('‹')
      .fontSize(28)
      .fontColor(Constants.COLOR_TEXT_PRIMARY)
      .width(36)
      .height(36)
      .textAlign(TextAlign.Center)
      .onClick(() => {
        onBack();
      })

    Column() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
      if (subtitle.length > 0) {
        Text(subtitle)
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ top: 2 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .margin({ left: 4 })
  }
  .width('100%')
  .padding({ left: 8, right: 20, top: 16, bottom: 12 })
}

/**
 * 渐变标题栏（带返回按钮 + 蓝色渐变背景）
 * 用于所有子页面的统一标题栏样式
 * @param title       主标题
 * @param subtitle    副标题（可选，传空字符串则不显示）
 */
@Builder
export function GradientHeader(title: string, subtitle: string, onBack: () => void) {
  Row() {
    Text('‹')
      .fontSize(28)
      .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
      .width(36)
      .height(36)
      .textAlign(TextAlign.Center)
      .onClick(() => {
        onBack();
      })
    Column() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
      if (subtitle.length > 0) {
        Text(subtitle)
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT_SUB)
          .margin({ top: 2 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .margin({ left: 4 })
  }
  .width('100%')
  .padding({ left: 8, right: 20, top: 16, bottom: 12 })
  .linearGradient({ angle: 135, colors: [[Constants.COLOR_GRADIENT_START, 0], [Constants.COLOR_GRADIENT_MID, 1]] })
}

/**
 * 空状态占位
 * @param message  提示文案
 */
@Builder
export function EmptyState(message: string) {
  Column() {
    Text(message)
      .fontSize(14)
      .fontColor(Constants.COLOR_TEXT_PLACEHOLDER)
  }
  .width('100%')
  .layoutWeight(1)
  .justifyContent(FlexAlign.Center)
}

/**
 * 加载状态占位
 */
@Builder
export function LoadingState() {
  Column() {
    LoadingProgress()
      .width(36)
      .height(36)
      .color(Constants.COLOR_BRAND)
  }
  .width('100%')
  .layoutWeight(1)
  .justifyContent(FlexAlign.Center)
}
