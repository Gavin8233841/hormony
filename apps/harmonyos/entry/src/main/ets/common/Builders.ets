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

export interface ResultTagSummary {
  tag: string;
  total: number;
  correct: number;
  wrong: number;
  accuracy: number;
  level: string;
  action: string;
}

export function buildResultTagSummaries(details: QuizResultDetail[], fallbackTag: string): ResultTagSummary[] {
  const summaries: ResultTagSummary[] = [];
  const normalizedFallback = normalizeResultTag(fallbackTag);
  const safeFallback = normalizedFallback.length > 0 ? normalizedFallback : '综合';
  for (const detail of details) {
    const seenTags: string[] = [];
    const sourceTags = detail.tags ?? [];
    for (const sourceTag of sourceTags) {
      const normalized = normalizeResultTag(sourceTag);
      if (normalized.length > 0 && !seenTags.includes(normalized)) {
        seenTags.push(normalized);
      }
    }
    if (seenTags.length === 0) {
      seenTags.push(safeFallback);
    }
    for (const tag of seenTags) {
      let summary = summaries.find((item: ResultTagSummary): boolean => item.tag === tag);
      if (summary === undefined) {
        summary = { tag, total: 0, correct: 0, wrong: 0, accuracy: 0, level: '', action: '' };
        summaries.push(summary);
      }
      summary.total += 1;
      if (detail.isCorrect) {
        summary.correct += 1;
      } else {
        summary.wrong += 1;
      }
    }
  }
  for (const summary of summaries) {
    summary.accuracy = summary.total > 0 ? summary.correct / summary.total : 0;
    if (summary.wrong > 0 && summary.accuracy < 0.6) {
      summary.level = '需复盘';
      summary.action = '先复盘错题，再练同标签 2-3 题';
    } else if (summary.wrong > 0) {
      summary.level = '待巩固';
      summary.action = '先复盘错题，再练同标签 2-3 题';
    } else if (summary.total < 2) {
      summary.level = '待确认';
      summary.action = '样本较少，再做 2 题确认稳定性';
    } else {
      summary.level = '本轮掌握';
      summary.action = '保持间隔复习，准备进入关联主题';
    }
  }
  return summaries.sort((left: ResultTagSummary, right: ResultTagSummary): number => {
    if (left.wrong !== right.wrong) return right.wrong - left.wrong;
    if (left.total !== right.total) return right.total - left.total;
    if (left.accuracy !== right.accuracy) return left.accuracy - right.accuracy;
    return left.tag < right.tag ? -1 : (left.tag > right.tag ? 1 : 0);
  }).slice(0, 4);
}

function normalizeResultTag(value?: string): string {
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (normalized.length === 0) return '';
  return normalized.length > 12 ? normalized.substring(0, 12) : normalized;
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
export function ResultTagSummaryPanel(
  title: string,
  summaries: ResultTagSummary[],
  actionLabel: string,
  onAction: (tag: string) => void
) {
  if (summaries.length > 0) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text(title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Constants.COLOR_TEXT_PRIMARY)
          Text('按标签看本轮得失')
            .fontSize(11)
            .fontColor(Constants.COLOR_TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(summaries.length.toString() + ' 个标签')
          .fontSize(11)
          .fontColor(Constants.COLOR_TEXT_TERTIARY)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(Constants.COLOR_BG_TAG)
          .borderRadius(10)
      }
      .width('100%')

      ForEach(summaries, (summary: ResultTagSummary): void => {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            Text(summary.tag)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
              .layoutWeight(1)
            Text(summary.level)
              .fontSize(11)
              .fontColor(summary.wrong > 0 ? Constants.COLOR_WARNING : Constants.COLOR_SUCCESS)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(summary.wrong > 0 ? Constants.COLOR_BG_TAG : Constants.COLOR_SUCCESS_LIGHT)
              .borderRadius(9)
            Text(Math.round(summary.accuracy * 100).toString() + '%')
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(summary.wrong > 0 ? Constants.COLOR_WARNING : Constants.COLOR_SUCCESS)
          }
          .width('100%')
          Progress({ value: summary.correct, total: Math.max(summary.total, 1), type: ProgressType.Linear })
            .width('100%')
            .height(6)
            .color(summary.wrong > 0 ? Constants.COLOR_WARNING : Constants.COLOR_SUCCESS)
            .backgroundColor(Constants.COLOR_BG_PROGRESS_TRACK)
            .borderRadius(3)
          Row({ space: 8 }) {
            Text(summary.total.toString() + ' 题 · 错 ' + summary.wrong.toString() + ' 题')
              .fontSize(11)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
              .layoutWeight(1)
            Button(actionLabel)
              .height(30)
              .fontSize(11)
              .fontColor(Constants.COLOR_BRAND)
              .padding({ left: 10, right: 10 })
              .backgroundColor(Constants.COLOR_BRAND_LIGHT)
              .borderRadius(15)
              .onClick((): void => { onAction(summary.tag); })
          }
          .width('100%')
          Text(summary.action)
            .width('100%')
            .fontSize(11)
            .lineHeight(17)
            .fontColor(Constants.COLOR_TEXT_TERTIARY)
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Constants.COLOR_BG_CARD)
        .borderRadius(Constants.RADIUS_MD)
        .border({ width: 1, color: Constants.COLOR_BORDER })
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Constants.COLOR_SURFACE_TINT)
    .borderRadius(Constants.RADIUS_LG)
  }
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
        .height(36)
        .padding({ left: 12, right: 12 })
        .backgroundColor(Constants.COLOR_BRAND_LIGHT)
        .borderRadius(Constants.RADIUS_MD)
        .alignSelf(ItemAlign.Start)
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
