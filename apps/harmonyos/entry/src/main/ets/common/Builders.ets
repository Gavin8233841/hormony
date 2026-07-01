/**
 * 全局共享 @Builder
 * 跨页面复用的 UI 片段
 */

import { Constants } from './Constants';
import { QuizResultDetail } from '../model/DataModels';

/**
 * 统一标题栏（带返回按钮）
 * @param title       主标题
 * @param subtitle    副标题（可选，传空字符串则不显示）
 */
@Builder
export function TitleBar(title: string, subtitle: string, onBack: () => void) {
  Row() {
    SymbolGlyph($r('sys.symbol.chevron_left'))
      .fontSize(22)
      .fontColor([Constants.COLOR_TEXT_PRIMARY])
      .width(40)
      .height(40)
      .onClick(() => {
        onBack();
      })

    Column() {
      Text(title)
        .fontSize(22)
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
  .padding({ left: 8, right: 20, top: 16, bottom: 14 })
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
    SymbolGlyph($r('sys.symbol.chevron_left'))
      .fontSize(22)
      .fontColor([Constants.COLOR_TEXT_PRIMARY])
      .width(40)
      .height(40)
      .onClick(() => {
        onBack();
      })
    Column() {
      Text(title)
        .fontSize(22)
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
  .padding({ left: 8, right: 20, top: 16, bottom: 14 })
  .backgroundColor(Constants.COLOR_BG_PAGE)
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

@Builder
export function AnswerOption(option: string, selected: boolean, onSelect: () => void) {
  Button({ type: ButtonType.Normal }) {
    Row({ space: 12 }) {
      Text(option.substring(0, 1))
        .width(30)
        .height(30)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(selected ? Constants.COLOR_TEXT_ON_GRADIENT : Constants.COLOR_TEXT_TERTIARY)
        .textAlign(TextAlign.Center)
        .backgroundColor(selected ? Constants.COLOR_BRAND : Constants.COLOR_BG_TAG)
        .borderRadius(15)
      Text(option.length > 2 ? option.substring(2).trim() : option)
        .layoutWeight(1)
        .fontSize(14)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
        .textAlign(TextAlign.Start)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (selected) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(19)
          .fontColor([Constants.COLOR_BRAND])
      }
    }
    .width('100%')
    .padding({ left: 13, right: 13 })
  }
  .width('100%')
  .constraintSize({ minHeight: 58 })
  .backgroundColor(selected ? Constants.COLOR_BRAND_LIGHT : Constants.COLOR_BG_CARD)
  .border({ width: 1, color: selected ? Constants.COLOR_BRAND : Constants.COLOR_BORDER })
  .borderRadius(Constants.RADIUS_MD)
  .onClick((): void => { onSelect(); })
}

@Builder
export function ReviewDetailRow(
  detail: QuizResultDetail,
  index: number,
  expanded: boolean,
  onToggle: () => void
) {
  Column({ space: 10 }) {
    Row({ space: 10 }) {
      SymbolGlyph($r(detail.isCorrect ? 'sys.symbol.checkmark_circle_fill' : 'sys.symbol.xmark_circle_fill'))
        .fontSize(20)
        .fontColor([detail.isCorrect ? Constants.COLOR_SUCCESS : Constants.COLOR_ERROR])
      Text((index + 1).toString() + '. ' + detail.stem)
        .layoutWeight(1)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Constants.COLOR_TEXT_PRIMARY)
        .lineHeight(22)
      SymbolGlyph($r(expanded ? 'sys.symbol.chevron_up' : 'sys.symbol.chevron_down'))
        .fontSize(15)
        .fontColor([Constants.COLOR_TEXT_SECONDARY])
    }
    .width('100%')

    if (expanded) {
      Column({ space: 7 }) {
        Text('你的答案：' + (detail.userAnswer.length > 0 ? detail.userAnswer : '未作答'))
          .width('100%')
          .fontSize(12)
          .fontColor(detail.isCorrect ? Constants.COLOR_SUCCESS : Constants.COLOR_ERROR)
        if (!detail.isCorrect) {
          Text('正确答案：' + detail.correctAnswer)
            .width('100%')
            .fontSize(12)
            .fontColor(Constants.COLOR_SUCCESS)
        }
        Text(detail.explanation)
          .width('100%')
          .fontSize(13)
          .lineHeight(21)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Constants.COLOR_SURFACE_TINT)
      .borderRadius(Constants.RADIUS_MD)
    }
  }
  .width('100%')
  .padding({ left: 14, right: 14, top: 14, bottom: 14 })
  .onClick((): void => { onToggle(); })
}
