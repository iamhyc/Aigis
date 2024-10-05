@Entry
@Component
struct ItemEditPage {
    build() {
        RelativeContainer() {
            Navigation() {
                Scroll() {
                    Column() {
                        Image($rawfile('issuer-icons/SVG/github.svg'))
                            .height('64vp')
                            .width('64vp')
                            .borderRadius('32vp')
                            .margin('20vp')

                        Divider().strokeWidth('1px')

                        TextInput({placeholder:'Name'}).margin({top:'16vp'})

                        TextInput({placeholder:'Issuer'}).margin({top:'16vp'})

                        TextInput({placeholder:'Secret'}).margin({top:'16vp'})
                            .type(InputType.Password)

                        Grid() {
                            GridItem() {
                                Select([
                                    {value: 'TOTP'},
                                    {value: 'HOTP'},
                                ]).value('Type').width('100%')
                            }.margin({top:'16vp'})
                            GridItem() {
                                Select([
                                    {value: 'SHA1'},
                                    {value: 'SHA256'},
                                    {value: 'SHA512'},
                                ]).value('Hash function').width('100%')
                            }.margin({top:'16vp'})
                            GridItem() {
                                TextInput({placeholder:'Period (seconds)'}).margin({top:'16vp'})
                                    .type(InputType.Number)
                            }
                            GridItem() {
                                TextInput({placeholder:'Counter'}).margin({top:'16vp'})
                                    .type(InputType.Number)
                            }
                            GridItem() {
                                TextInput({placeholder:'Digits'}).margin({top:'16vp'})
                                    .type(InputType.Number)
                            }
                            GridItem() {
                                TextInput({placeholder:'Usage count'}).margin({top:'16vp'})
                                    .type(InputType.Number).enabled(false)
                            }
                        }
                        .columnsTemplate('1fr 1fr')
                        .maxCount(2)
                        .layoutDirection(GridDirection.Row)

                        Button() {
                            Text('Save')
                        }
                        .height('36vp')
                        .width('100%')
                        .margin({top:'16vp'})
                    }
                    .padding({left:10, right:10})
                }
            }
            .title($r('app.string.ItemEditPage_title'), {
                // backgroundColor: $r('app.color.color_background'),
            })
            .titleMode(NavigationTitleMode.Mini)
            .mode(NavigationMode.Auto)
            .backgroundColor($r('app.color.color_face'))
        }
        .height('100%')
        .width('100%')
    }
}