let storage = new LocalStorage();

@Entry(storage)
@Component
struct LearningPlanCard {
  @LocalStorageProp('kind') kind: string = 'plan';
  @LocalStorageProp('badge') badge: string = '今日起步';
  @LocalStorageProp('title') title: string = '制定今天的学习计划';
  @LocalStorageProp('subtitle') subtitle: string = '让学伴把目标拆成可执行任务';
  @LocalStorageProp('cta') cta: string = '制定计划';
  @LocalStorageProp('courseId') courseId: string = '';
  @LocalStorageProp('courseTitle') courseTitle: string = '';
  @LocalStorageProp('topic') topic: string = '';
  @LocalStorageProp('focusTag') focusTag: string = '';
  @LocalStorageProp('taskAction') taskAction: string = 'plan';
  @LocalStorageProp('targetPage') targetPage: string = 'pages/Plan';
  @LocalStorageProp('evidence') evidence: string = '本机还没有可继续的课程状态或今日任务';
  @LocalStorageProp('progressText') progressText: string = '等待制定计划';

  build() {
    FormLink({
      action: 'router',
      abilityName: 'EntryAbility',
      params: {
        source: 'proactive_learning_card',
        targetPage: this.targetPage,
        courseId: this.courseId,
        courseTitle: this.courseTitle,
        topic: this.topic,
        focusTag: this.focusTag,
        taskAction: this.taskAction
      }
    }) {
      Column() {
        Row() {
          Text('鸿学伴')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#176BFF')
          Text(this.badge)
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor('#176BFF')
            .maxLines(1)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#EAF2FF')
            .borderRadius(8)
            .margin({ left: 8 })
          Blank()
          SymbolGlyph($r('sys.symbol.book_open_fill'))
            .fontSize(28)
            .fontColor(['#176BFF'])
        }
        .width('100%')

        Blank()

        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111827')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.subtitle)
            .fontSize(12)
            .fontColor('#6F7A8F')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.evidence)
            .fontSize(10)
            .fontColor('#6F7A8F')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Row() {
          Text(this.progressText)
            .fontSize(12)
            .fontColor('#176BFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Row({ space: 2 }) {
            Text(this.cta)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .maxLines(1)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(13)
              .fontColor(['#FFFFFF'])
          }
          .height(32)
          .padding({ left: 12, right: 9 })
          .backgroundColor('#176BFF')
          .borderRadius(16)
        }
        .width('100%')
        .margin({ top: 10 })
      }
      .width('100%')
      .height('100%')
      .padding(16)
      .backgroundColor('#F4F7FC')
    }
  }
}
