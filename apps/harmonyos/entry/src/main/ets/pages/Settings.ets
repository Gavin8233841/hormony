import { common } from '@kit.AbilityKit';
import { TitleBar } from '../common/Builders';
import { Constants } from '../common/Constants';
import { SafeAreaInsets } from '../common/SafeArea';
import { ThemeMode, ThemePreference } from '../common/ThemePreference';

@Entry
@Component
struct SettingsPage {
  @StorageProp('darkMode') darkMode: boolean = false;
  @StorageProp('themeMode') themeMode: string = ThemeMode.SYSTEM;
  @State saving: boolean = false;
  @State message: string = '';

  private async selectMode(mode: ThemeMode): Promise<void> {
    if (this.saving || this.themeMode === mode) return;
    const host = this.getUIContext().getHostContext();
    if (host === undefined) {
      this.message = '外观设置暂时无法保存，请重试';
      return;
    }
    const context = host as common.UIAbilityContext;
    const previous = this.themeMode as ThemeMode;
    this.saving = true;
    this.message = '';
    try {
      await ThemePreference.save(context, mode);
      ThemePreference.apply(context, mode);
    } catch (_) {
      try {
        await ThemePreference.save(context, previous);
      } catch (_) {
      }
      this.message = '外观设置暂时无法保存，请重试';
    } finally {
      this.saving = false;
    }
  }

  @Builder
  private ModeOption(mode: ThemeMode, label: string) {
    Text(label)
      .width('100%')
      .height(46)
      .fontSize(13)
      .fontWeight(this.themeMode === mode ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.themeMode === mode ? Constants.COLOR_BRAND_TEXT : Constants.COLOR_TEXT_SECONDARY)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.themeMode === mode ? Constants.COLOR_BRAND_LIGHT : Color.Transparent)
      .borderRadius(Constants.RADIUS_SM)
      .onClick((): void => { this.selectMode(mode); })
      .accessibilityText(label)
      .accessibilityDescription(this.themeMode === mode ? '已选中' : '切换外观')
  }

  build() {
    Column() {
      TitleBar('设置', '', () => this.getUIContext().getRouter().back())
      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 12 }) {
            Text('外观')
              .width('100%')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(Constants.COLOR_TEXT_PRIMARY)
            Text('选择你喜欢的显示方式')
              .width('100%')
              .fontSize(12)
              .fontColor(Constants.COLOR_TEXT_SECONDARY)
            Row({ space: 4 }) {
              Column() { this.ModeOption(ThemeMode.SYSTEM, '跟随系统') }.layoutWeight(1)
              Column() { this.ModeOption(ThemeMode.LIGHT, '浅色') }.layoutWeight(1)
              Column() { this.ModeOption(ThemeMode.DARK, '深色') }.layoutWeight(1)
            }
            .width('100%')
            .padding(4)
            .backgroundColor(Constants.COLOR_BG_TAG)
            .borderRadius(Constants.RADIUS_MD)
            .accessibilityGroup(true)
            .accessibilityText('外观，' + (this.themeMode === ThemeMode.SYSTEM ? '跟随系统' :
              (this.themeMode === ThemeMode.LIGHT ? '浅色' : '深色')))
          }
          .width('100%')
          .padding(18)
          .alignItems(HorizontalAlign.Start)
          .backgroundColor(Constants.COLOR_BG_CARD)
          .borderRadius(Constants.RADIUS_LG)

          if (this.message.length > 0) {
            Text(this.message)
              .width('100%')
              .fontSize(12)
              .fontColor(Constants.COLOR_ERROR)
              .padding(12)
              .backgroundColor(Constants.COLOR_ERROR_LIGHT)
              .borderRadius(Constants.RADIUS_SM)
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16, right: 16, top: 12, bottom: 24 + SafeAreaInsets.bottomVp() })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .backgroundColor(Constants.COLOR_BG_PAGE)
  }
}
