/**
 * 鸿学伴 - 首页
 * 渐变头部 + 学习概览 + 快捷入口
 */

import router from '@ohos.router';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HttpClient } from '../common/HttpClient';
import { Constants } from '../common/Constants';
import { StatCard } from '../common/Builders';
import { UserProfile } from '../model/DataModels';

@Entry
@Component
struct Index {
  @State profile: UserProfile | null = null;
  @State message: string = '';
  @State appearOpacity: number = 0;
  @State appearOffset: number = 20;
  @State pressedId: number = -1;

  aboutToAppear() {
    // 调试模式：先加载演示数据，避免网络等待时空白
    if (Constants.__DEBUG__) {
      this.profile = {
        userId: 'demo',
        name: '演示同学',
        stage: '本科二年级',
        weakTopics: ['树与图', '动态规划', '操作系统调度'],
        strongTopics: ['数组', '链表', '基础语法'],
        learningStyle: '视觉型',
        stats: { totalQuestions: 128, accuracy: 0.76, studyDays: 23 },
      };
    }
    this.loadProfile();
    // 入场动画
    setTimeout(() => {
      animateTo({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut }, () => {
        this.appearOpacity = 1;
        this.appearOffset = 0;
      });
    }, 100);
  }

  async loadProfile() {
    try {
      this.profile = await HttpClient.get<UserProfile>(
        Constants.API_PROFILE + '?userId=' + Constants.DEMO_USER_ID
      );
    } catch (e) {
      if (!Constants.__DEBUG__) {
        const errMsg: string = e instanceof Error ? e.message : '未知错误';
        this.message = '加载失败: ' + errMsg;
      }
    }
  }

  @Builder
  FunctionEntry(index: number, title: string, subtitle: string, accentColor: ResourceColor, action: () => void) {
    Row() {
      // 左侧色条
      Column()
        .width(4)
        .height(36)
        .backgroundColor(accentColor)
        .borderRadius(2)

      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
        Text(subtitle)
          .fontSize(12)
          .fontColor(Constants.COLOR_TEXT_SECONDARY)
          .margin({ top: 3 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 14 })

      Text('›')
        .fontSize(22)
        .fontColor(Constants.COLOR_TEXT_PLACEHOLDER)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(Constants.COLOR_BG_CARD)
    .borderRadius(Constants.RADIUS_LG)
    .shadow({ radius: 16, color: Constants.SHADOW_CARD, offsetX: 0, offsetY: 2 })
    .alignItems(VerticalAlign.Center)
    .scale({ x: this.pressedId === index ? 0.97 : 1, y: this.pressedId === index ? 0.97 : 1 })
    .animation({ duration: 100, curve: Curve.EaseOut })
    .onTouch((event?: TouchEvent) => {
      if (event) {
        if (event.type === TouchType.Down) {
          this.pressedId = index;
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressedId = -1;
        }
      }
    })
    .onClick(() => {
      action();
    })
  }

  build() {
    Column() {
      // 渐变头部
      Column() {
        Text('鸿学伴')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT)
          .width('100%')

        Text('今天学什么？')
          .fontSize(14)
          .fontColor(Constants.COLOR_TEXT_ON_GRADIENT_SUB)
          .margin({ top: 4 })
          .width('100%')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 44, bottom: 28 })
      .linearGradient({
        angle: 135,
        colors: [[Constants.COLOR_GRADIENT_START, 0], [Constants.COLOR_GRADIENT_MID, 0.5], [Constants.COLOR_GRADIENT_END, 1]]
      })

      // 内容区（带入场动画）
      Column() {
        // 学习概览卡片
        Row({ space: 10 }) {
          StatCard(
            this.profile?.stats?.totalQuestions?.toString() ?? '0',
            '提问',
            Constants.COLOR_BRAND
          )
          StatCard(
            this.profile ? Math.round(this.profile.stats.accuracy * 100).toString() + '%' : '0%',
            '正确率',
            Constants.COLOR_SUCCESS
          )
          StatCard(
            this.profile?.stats?.studyDays?.toString() ?? '0',
            '学习天',
            Constants.COLOR_WARNING
          )
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

        // 快捷功能区标题
        Text('学习功能')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Constants.COLOR_TEXT_PRIMARY)
          .width('100%')
          .padding({ left: 24, top: 28, bottom: 8 })

        // 功能入口
        Column({ space: 10 }) {
          this.FunctionEntry(0, '问问鸿学伴', '向 AI 助教提问，获取带引用的讲解', Constants.COLOR_BRAND, () => {
            router.pushUrl({ url: 'pages/Chat' }).catch((err: Error) => {
              hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG, 'Index router.pushUrl failed: %{public}s', err.message);
            });
          })
          this.FunctionEntry(1, '学习计划', '输入目标，自动拆解为每日任务', Constants.COLOR_SUCCESS, () => {
            router.pushUrl({ url: 'pages/Plan' }).catch((err: Error) => {
              hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG, 'Index router.pushUrl failed: %{public}s', err.message);
            });
          })
          this.FunctionEntry(2, '搜课程资料', '搜索课程知识点和相关资料', Constants.COLOR_WARNING, () => {
            router.pushUrl({ url: 'pages/Knowledge' }).catch((err: Error) => {
              hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG, 'Index router.pushUrl failed: %{public}s', err.message);
            });
          })
          this.FunctionEntry(3, '我的课程', '查看课程进度和学习资料', Constants.COLOR_ACCENT_PURPLE, () => {
            router.pushUrl({ url: 'pages/Course' }).catch((err: Error) => {
              hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG, 'Index router.pushUrl failed: %{public}s', err.message);
            });
          })
          this.FunctionEntry(4, '学习画像', '查看薄弱点和优势，针对性提升', Constants.COLOR_ACCENT_CYAN, () => {
            router.pushUrl({ url: 'pages/Profile' }).catch((err: Error) => {
              hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG, 'Index router.pushUrl failed: %{public}s', err.message);
            });
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })

        // 底部留白
        Blank().height(40)

        if (this.message.length > 0) {
          Text(this.message)
            .fontSize(12)
            .fontColor(Constants.COLOR_ERROR)
            .padding({ left: 24, right: 24, bottom: 8 })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .opacity(this.appearOpacity)
      .translate({ y: this.appearOffset })
      .animation({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Left)
    PageTransitionExit({ duration: 300, curve: Curve.EaseOut })
      .slide(SlideEffect.Right)
  }
}
