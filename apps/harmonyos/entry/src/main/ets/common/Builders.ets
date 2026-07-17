/**
 * 全局共享 @Builder
 * 跨页面复用的 UI 片段
 */

import { Constants } from './Constants';
import { LearningQuizResultDetail as QuizResultDetail } from '../model/LearningMetadataModels';
import { SafeAreaInsets } from './SafeArea';

export interface WorkStep {
  title: string;
  description: string;
}

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
  .padding({ left: 8, right: 20, top: 16 + SafeAreaInsets.topVp(), bottom: 14 })
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
  .padding({ left: 8, right: 20, top: 16 + SafeAreaInsets.topVp(), bottom: 14 })
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
export function StagedProgress(title: string, subtitle: string, activeIndex: number, steps: WorkStep[]) {
  Column({ space: 12 }) {
    Row({ space: 9 }) {
      LoadingProgress()
        .width(22)
        .height(22)
        .color(Constants.COLOR_BRAND)
      Column({ space: 3 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text(subtitle)
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    Progress({ value: Math.min((activeIndex + 1) * 100 / Math.max(steps.length, 1), 90), total: 100,
      type: ProgressType.Linear })
      .width('100%')
      .color(Constants.COLOR_BRAND)
      .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
      .borderRadius(4)
    Row() {
      ForEach(steps, (step: WorkStep, index: number): void => {
        Column({ space: 3 }) {
          Column()
            .width(8)
            .height(8)
            .backgroundColor(index <= activeIndex ? Constants.COLOR_BRAND : Constants.COLOR_BG_PROGRESS_TRACK)
            .borderRadius(4)
          Text(step.title)
            .fontSize(10)
            .fontColor(index <= activeIndex ? Constants.COLOR_TEXT_TERTIARY : Constants.COLOR_TEXT_PLACEHOLDER)
        }
        .layoutWeight(1)
        .alignItems(index === 0 ? HorizontalAlign.Start : (index === steps.length - 1 ? HorizontalAlign.End :
          HorizontalAlign.Center))
      })
    }
    .width('100%')
  }
  .width('100%')
  .padding(14)
  .backgroundColor(Constants.COLOR_SURFACE_TINT)
  .borderRadius(Constants.RADIUS_MD)
}

@Builder
export function AnswerOption(option: string, selected: boolean, enabled: boolean, onSelect: () => void) {
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
  .enabled(enabled)
  .accessibilityText(option + (selected ? '，已选择' : '，未选择'))
  .accessibilityDescription(enabled ? '选择此答案' : '答案已冻结，等待确认写回')
  .onClick((): void => { onSelect(); })
}

@Builder
export function ReviewDetailRow(
  detail: QuizResultDetail,
  index: number,
  expanded: boolean,
  onToggle: () => void,
  onAskTutor: () => void
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
    .constraintSize({ minHeight: 48 })
    .accessibilityGroup(true)
    .accessibilityText('第 ' + (index + 1).toString() + ' 题，' +
      (detail.isCorrect ? '回答正确' : '回答错误') + (expanded ? '，解析已展开' : '，解析已收起'))
    .accessibilityDescription(expanded ? '收起本题解析' : '展开本题解析')
    .onClick((): void => { onToggle(); })

    if (expanded) {
      Column({ space: 7 }) {
        if ((detail.tags ?? []).length > 0 || detail.difficulty !== undefined) {
          Flex({ wrap: FlexWrap.Wrap }) {
            if (detail.difficulty !== undefined) {
              Text(detail.difficulty === 'easy' ? '基础' : (detail.difficulty === 'hard' ? '挑战' : '进阶'))
                .fontSize(10)
                .fontColor(Constants.COLOR_TEXT_TERTIARY)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(Constants.COLOR_BG_TAG)
                .borderRadius(9)
                .margin({ right: 6, bottom: 6 })
            }
            ForEach(detail.tags ?? [], (tag: string): void => {
              Text(tag)
                .fontSize(10)
                .fontColor(Constants.COLOR_BRAND)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(Constants.COLOR_BRAND_LIGHT)
                .borderRadius(9)
                .margin({ right: 6, bottom: 6 })
            })
          }
          .width('100%')
        }
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
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            SymbolGlyph($r('sys.symbol.ellipsis_message_fill'))
              .fontSize(15)
              .fontColor([Constants.COLOR_BRAND])
            Text('向学伴追问')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_BRAND)
          }
        }
        .height(48)
        .padding({ left: 12, right: 12 })
        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
        .borderRadius(Constants.RADIUS_MD)
        .alignSelf(ItemAlign.Start)
        .accessibilityText('向学伴追问第 ' + (index + 1).toString() + ' 题')
        .accessibilityDescription('携带本题、你的答案和正确答案打开学伴')
        .onClick((): void => { onAskTutor(); })
      }
      .width('100%')
      .padding(12)
      .backgroundColor(Constants.COLOR_SURFACE_TINT)
      .borderRadius(Constants.RADIUS_MD)
    }
  }
  .width('100%')
  .padding({ left: 14, right: 14, top: 14, bottom: 14 })
}
