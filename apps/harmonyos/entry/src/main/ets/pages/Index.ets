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
import uiMaterial from '@ohos.arkui.uiMaterial';

@Entry
@Component
struct Index {
  @StorageProp('darkMode') darkMode: boolean = false;
  @State currentIndex: number = 0;
  @State quickQuestion: string = '';
  @State learningViewVersion: number = 0;
  @StorageProp('safeAreaTopVp') safeAreaTopVpValue: number = 0;
  @StorageProp('safeAreaBottomVp') safeAreaBottomVpValue: number = 0;
  @StorageLink('proactiveLaunchVersion') @Watch('consumeProactiveLaunch') proactiveLaunchVersion: number = 0;
  private consumedLaunchVersion: number = -1;
  private navigatingLaunchVersion: number = -1;
  private retryLaunchVersion: number = -1;

  aboutToAppear(): void {
    this.consumeProactiveLaunch();
  }

  onPageShow(): void {
    this.learningViewVersion += 1;
  }

  private safeAreaTopVp(): number {
    return Math.max(0, this.safeAreaTopVpValue);
  }

  private safeAreaBottomVp(): number {
    return Math.max(0, this.safeAreaBottomVpValue);
  }

  private navigationBottomPadding(): number {
    return 8 + this.safeAreaBottomVp();
  }

  private consumeProactiveLaunch(): void {
    if (this.consumedLaunchVersion === this.proactiveLaunchVersion) return;
    if (this.navigatingLaunchVersion >= 0) return;
    const targetPage = AppStorage.get<string>('proactiveTargetPage') ?? '';
    if (targetPage.length === 0) return;
    const launchVersion = this.proactiveLaunchVersion;
    this.navigatingLaunchVersion = launchVersion;
    setTimeout((): void => {
      this.navigateProactiveLaunch(launchVersion, targetPage);
    }, 0);
  }

  private navigateProactiveLaunch(launchVersion: number, targetPage: string): void {
    if (launchVersion !== this.proactiveLaunchVersion ||
      targetPage !== (AppStorage.get<string>('proactiveTargetPage') ?? '')) {
      this.releaseProactiveNavigation(launchVersion);
      return;
    }
    if (!ProactiveLearningService.isTargetPage(targetPage)) {
      AppStorage.setOrCreate<string>('proactiveTargetPage', '');
      this.consumedLaunchVersion = launchVersion;
      this.releaseProactiveNavigation(launchVersion);
      return;
    }
    try {
      const appRouter = this.getUIContext().getRouter();
      const currentPage = appRouter.getState().path;
      if (targetPage === 'pages/Index') {
        const targetTab = AppStorage.get<number>('proactiveTargetTab') ?? 0;
        this.selectTab(targetTab >= 0 && targetTab <= 3 ? targetTab : 0);
        if (currentPage === 'pages/Index') {
          this.completeProactiveNavigation(launchVersion, targetPage);
          return;
        }
        appRouter.back({ url: 'pages/Index' });
        setTimeout((): void => {
          try {
            if (appRouter.getState().path === 'pages/Index') {
              this.completeProactiveNavigation(launchVersion, targetPage);
            } else {
              this.failProactiveNavigation(launchVersion, '未能返回应用根页');
            }
          } catch (error) {
            const message = error instanceof Error ? error.message : JSON.stringify(error);
            this.failProactiveNavigation(launchVersion, message);
          }
        }, 0);
        return;
      }
      const navigation = currentPage === 'pages/Index' ?
        appRouter.pushUrl({ url: targetPage }) : appRouter.replaceUrl({ url: targetPage });
      navigation.then((): void => {
        this.completeProactiveNavigation(launchVersion, targetPage);
      }).catch((error: Error): void => {
        this.failProactiveNavigation(launchVersion, error.message);
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : JSON.stringify(error);
      this.failProactiveNavigation(launchVersion, message);
    }
  }

  private completeProactiveNavigation(launchVersion: number, targetPage: string): void {
    if (launchVersion === this.proactiveLaunchVersion &&
      targetPage === (AppStorage.get<string>('proactiveTargetPage') ?? '')) {
      AppStorage.setOrCreate<string>('proactiveTargetPage', '');
      this.consumedLaunchVersion = launchVersion;
      this.retryLaunchVersion = -1;
    }
    this.releaseProactiveNavigation(launchVersion);
  }

  private failProactiveNavigation(launchVersion: number, message: string): void {
    hilog.error(Constants.HILOG_DOMAIN, Constants.HILOG_TAG,
      'Index proactive launch navigation failed: %{public}s', message);
    this.releaseProactiveNavigation(launchVersion);
    if (launchVersion === this.proactiveLaunchVersion && this.retryLaunchVersion !== launchVersion) {
      this.retryLaunchVersion = launchVersion;
      setTimeout((): void => {
        this.consumeProactiveLaunch();
      }, 200);
    }
  }

  private releaseProactiveNavigation(launchVersion: number): void {
    if (this.navigatingLaunchVersion === launchVersion) {
      this.navigatingLaunchVersion = -1;
    }
    if (this.consumedLaunchVersion !== this.proactiveLaunchVersion &&
      launchVersion !== this.proactiveLaunchVersion) {
      setTimeout((): void => {
        this.consumeProactiveLaunch();
      }, 0);
    }
  }

  private selectTab(index: number): void {
    if (this.currentIndex === index) {
      return;
    }
    this.currentIndex = index;
    this.learningViewVersion += 1;
  }

  @Builder
  NativeTabItem(title: string, icon: Resource, selectedIcon: Resource, index: number) {
    Column({ space: 2 }) {
      Stack({ alignContent: Alignment.Center }) {
        Column()
          .width(42)
          .height(32)
          .backgroundColor(this.currentIndex === index ? Constants.COLOR_BRAND_LIGHT : Color.Transparent)
          .borderRadius(16)
        Image(this.currentIndex === index ? selectedIcon : icon)
          .width(23)
          .height(23)
          .objectFit(ImageFit.Contain)
          .fillColor(this.currentIndex === index ? Constants.COLOR_BRAND_TEXT : Constants.COLOR_NAV_INACTIVE)
          .scale({ x: this.currentIndex === index ? 1.08 : 1, y: this.currentIndex === index ? 1.08 : 1 })
          .animation({ duration: 180, curve: Curve.EaseOut })
      }
      .width(46)
      .height(32)
      .animation({ duration: 180, curve: Curve.EaseOut })
      Text(title)
        .fontSize(11)
        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentIndex === index ? Constants.COLOR_BRAND_TEXT : Constants.COLOR_NAV_INACTIVE)
        .height(17)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .animation({ duration: 180, curve: Curve.EaseOut })
    }
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .height('100%')
    .accessibilityText(title + (this.currentIndex === index ? '，当前页面' : ''))
  }

  @Builder
  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        HomeContent({
          selectedTab: $currentIndex,
          quickQuestion: $quickQuestion,
          learningViewVersion: this.learningViewVersion,
          bottomInset: Constants.NAV_HEIGHT + 20 + this.safeAreaBottomVp(),
        })
          .padding({ top: this.safeAreaTopVp() })
      }
      .tabBar(this.NativeTabItem('今日', $rawfile('nav-icons/calendar-check.svg'),
        $rawfile('nav-icons/calendar-check-duotone.svg'), 0))

      TabContent() {
        CourseContent({
          learningViewVersion: this.learningViewVersion,
          bottomInset: Constants.NAV_HEIGHT + 20 + this.safeAreaBottomVp(),
        })
          .padding({ top: this.safeAreaTopVp() })
      }
      .tabBar(this.NativeTabItem('课程', $rawfile('nav-icons/books.svg'),
        $rawfile('nav-icons/books-duotone.svg'), 1))

      TabContent() {
        ChatContent({
          quickQuestion: this.quickQuestion,
          bottomInset: Constants.NAV_HEIGHT + 20 + this.safeAreaBottomVp(),
        })
          .padding({ top: this.safeAreaTopVp() })
      }
      .tabBar(this.NativeTabItem('学伴', $rawfile('nav-icons/chat-circle-dots.svg'),
        $rawfile('nav-icons/chat-circle-dots-duotone.svg'), 2))

      TabContent() {
        ProfileContent({ bottomInset: Constants.NAV_HEIGHT + 20 + this.safeAreaBottomVp() })
          .padding({ top: this.safeAreaTopVp() })
      }
      .tabBar(this.NativeTabItem('我的', $rawfile('nav-icons/user-circle.svg'),
        $rawfile('nav-icons/user-circle-duotone.svg'), 3))
    }
    .width('100%')
    .height('100%')
    .barHeight(Constants.NAV_HEIGHT)
    .barMode(BarMode.Fixed)
    .scrollable(false)
    .barOverlap(true)
    .barFloatingStyle({
      barSideMargin: 20,
      barBottomMargin: this.navigationBottomPadding(),
      maskHeight: 100,
      maskColor: this.darkMode ? '#14202e40' : '#d7f7f9fd',
      systemMaterial: new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.THIN,
        materialColor: this.darkMode ? '#442b3d55' : '#64f5f8fc',
        applyShadow: true,
        interactive: true,
      }),
    })
    .onChange((index: number): void => {
      this.selectTab(index);
    })
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
