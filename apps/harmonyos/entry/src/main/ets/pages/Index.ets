/**
 * 鸿学伴主框架
 * 四个原生顶层入口 + 浮动底部导航
 */

import { Constants } from '../common/Constants';
import { ChatContent } from './Chat';
import { CourseContent } from './Course';
import { HomeContent } from './HomeContent';
import { ProfileContent } from './Profile';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State quickQuestion: string = '';

  private selectTab(index: number): void {
    this.currentIndex = index;
  }

  @Builder
  TabItem(title: string, icon: Resource, selectedIcon: Resource, index: number) {
    Column({ space: 4 }) {
      SymbolGlyph(this.currentIndex === index ? selectedIcon : icon)
        .fontSize(23)
        .fontColor([this.currentIndex === index ? Constants.COLOR_BRAND : Constants.COLOR_NAV_INACTIVE])
        .symbolEffect(new BounceSymbolEffect(EffectScope.WHOLE, EffectDirection.UP), this.currentIndex === index)
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
    .height(72)
    .backgroundColor('#f2ffffff')
    .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
    .borderRadius(Constants.RADIUS_XL)
    .shadow({ radius: 8, color: Constants.SHADOW_CARD_LG, offsetX: 0, offsetY: 4 })
    .zIndex(2)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.currentIndex === 0) {
        HomeContent({
          selectedTab: $currentIndex,
          quickQuestion: $quickQuestion,
        })
      } else if (this.currentIndex === 1) {
        Column() {
          CourseContent({ embedded: true })
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: 88 })
      } else if (this.currentIndex === 2) {
        Column() {
          ChatContent({ embedded: true, quickQuestion: this.quickQuestion })
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: 88 })
      } else {
        Column() {
          ProfileContent({ embedded: true })
        }
        .width('100%')
        .height('100%')
        .padding({ bottom: 88 })
      }

      Column() {
        Blank()
        this.BottomNavigation()
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 12 })
      .hitTestBehavior(HitTestMode.Transparent)
      .zIndex(2)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
