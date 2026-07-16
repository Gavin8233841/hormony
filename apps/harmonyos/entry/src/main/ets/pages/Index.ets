/**
 * 鸿学伴主框架
 * 四个原生顶层入口 + 浮动底部导航
 */

import { Constants } from '../common/Constants';
import { ChatContent } from './Chat';
import { CourseContent } from './Course';
import { HomeContent } from './HomeContent';
import { ProfileContent } from './Profile';
import { ProactiveLearningService } from '../common/ProactiveLearningService';
import { hilog } from '@kit.PerformanceAnalysisKit';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State quickQuestion: string = '';
  @State contentOpacity: number = 1;
  @State contentOffset: number = 0;
  @StorageProp('safeAreaTopVp') safeAreaTopVpValue: number = 0;
  @StorageProp('safeAreaBottomVp') safeAreaBottomVpValue: number = 0;
  @StorageLink('proactiveLaunchVersion') @Watch('consumeProactiveLaunch') proactiveLaunchVersion: number = 0;
  private consumedLaunchVersion: number = -1;

  aboutToAppear(): void {
    this.consumeProactiveLaunch();
  }

  private safeAreaTopVp(): number {
    return Math.max(0, this.safeAreaTopVpValue);
  }

  private safeAreaBottomVp(): number {
    return Math.max(0, this.safeAreaBottomVpValue);
  }

  private contentBottomPadding(): number {
    return 88 + this.safeAreaBottomVp();
  }

  private navigationBottomPadding(): number {
    return 12 + this.safeAreaBottomVp();
  }

  private consumeProactiveLaunch(): void {
    if (this.consumedLaunchVersion === this.proactiveLaunchVersion) return;
    this.consumedLaunchVersion = this.proactiveLaunchVersion;
    const targetPage = AppStorage.get<string>('proactiveTargetPage') ?? '';
    if (targetPage.length === 0) return;
    AppStorage.setOrCreate<string>('proactiveTargetPage', '');
    if (targetPage === 'pages/Index') {
      const targetTab = AppStorage.get<number>('proactiveTargetTab') ?? 0;
      this.selectTab(targetTab >= 0 && targetTab <= 3 ? targetTab : 0);
      return;
    }
    if (!ProactiveLearningService.isTargetPage(targetPage)) return;
    setTimeout((): void => {
      this.getUIContext().getRouter().pushUrl({ url: targetPage }).catch((error: Error): void => {
        hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
          'Index proactive launch navigation failed: %{public}s', error.message);
      });
    }, 0);
  }

  private selectTab(index: number): void {
    if (this.currentIndex === index) {
      return;
    }
    this.currentIndex = index;
    this.contentOpacity = 0.86;
    this.contentOffset = 6;
    this.getUIContext().animateTo({ duration: Constants.ANIM_NORMAL, curve: Curve.EaseOut }, (): void => {
      this.contentOpacity = 1;
      this.contentOffset = 0;
    });
  }

  @Builder
  TabItem(title: string, icon: Resource, selectedIcon: Resource, index: number) {
    Column({ space: 4 }) {
      SymbolGlyph(this.currentIndex === index ? selectedIcon : icon)
        .fontSize(23)
        .fontColor([this.currentIndex === index ? Constants.COLOR_BRAND : Constants.COLOR_NAV_INACTIVE])
        .scale({ x: this.currentIndex === index ? 1.06 : 1, y: this.currentIndex === index ? 1.06 : 1 })
        .animation({ duration: Constants.ANIM_FAST, curve: Curve.EaseOut })
      Text(title)
        .fontSize(11)
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentIndex === index ? Constants.COLOR_BRAND : Constants.COLOR_NAV_INACTIVE)
    }
    .width('25%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.selectTab(index);
    })
  }

  @Builder
  BottomNavigation() {
    Row() {
      this.TabItem('今日', $r('sys.symbol.calendar'), $r('sys.symbol.calendar_fill'), 0)
      this.TabItem('课程', $r('sys.symbol.book_open_fill'), $r('sys.symbol.book_open_fill'), 1)
      this.TabItem('学伴', $r('sys.symbol.ellipsis_message'), $r('sys.symbol.ellipsis_message_fill'), 2)
      this.TabItem('我的', $r('sys.symbol.person'), $r('sys.symbol.person_2_fill'), 3)
    }
    .width('90%')
    .constraintSize({ maxWidth: 520 })
    .height(72)
    .backgroundColor(Constants.COLOR_NAV_SURFACE)
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(Constants.RADIUS_XL)
    .shadow({ radius: 8, color: Constants.SHADOW_CARD_LG, offsetX: 0, offsetY: 4 })
    .zIndex(2)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        if (this.currentIndex === 0) {
          Column() {
            HomeContent({
              selectedTab: $currentIndex,
              quickQuestion: $quickQuestion,
            })
          }
          .width('100%')
          .height('100%')
          .padding({ bottom: this.contentBottomPadding() })
        } else if (this.currentIndex === 1) {
          Column() {
            CourseContent()
          }
          .width('100%')
          .height('100%')
          .padding({ bottom: this.contentBottomPadding() })
        } else if (this.currentIndex === 2) {
          Column() {
            ChatContent({ quickQuestion: this.quickQuestion })
          }
          .width('100%')
          .height('100%')
          .padding({ bottom: this.contentBottomPadding() })
        } else {
          Column() {
            ProfileContent()
          }
          .width('100%')
          .height('100%')
          .padding({ bottom: this.contentBottomPadding() })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.safeAreaTopVp() })
      .opacity(this.contentOpacity)
      .translate({ y: this.contentOffset })

      Column() {
        Blank()
        this.BottomNavigation()
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: this.navigationBottomPadding() })
      .hitTestBehavior(HitTestMode.Transparent)
      .zIndex(2)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
