let storage = new LocalStorage();

@Entry(storage)
@Component
struct LearningPlanCard {
  @LocalStorageProp('taskTitle') taskTitle: string = '打开鸿学伴制定今日计划';
  @LocalStorageProp('taskMeta') taskMeta: string = '计划保存在本机';
  @LocalStorageProp('progressText') progressText: string = '今日待开始';

  build() {
    FormLink({
      action: 'router',
      abilityName: 'EntryAbility',
      params: {
        source: 'learning_plan_card'
      }
    }) {
      Column() {
        Row() {
          Column({ space: 4 }) {
            Text('鸿学伴')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#246BFD')
            Text('今日学习')
              .fontSize(23)
              .fontWeight(FontWeight.Bold)
              .fontColor('#111827')
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          SymbolGlyph($r('sys.symbol.book_open_fill'))
            .fontSize(30)
            .fontColor(['#246BFD'])
        }
        .width('100%')

        Blank()

        Column({ space: 5 }) {
          Text(this.taskTitle)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.taskMeta)
            .fontSize(12)
            .fontColor('#667085')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text(this.progressText)
            .fontSize(12)
            .fontColor('#246BFD')
          Blank()
          Text('打开')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .padding({ left: 14, right: 14, top: 6, bottom: 6 })
            .backgroundColor('#246BFD')
            .borderRadius(15)
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .padding(18)
      .backgroundColor('#F7FAFF')
    }
  }
}
