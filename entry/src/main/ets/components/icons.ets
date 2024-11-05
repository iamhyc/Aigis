
function stringToColorHex(str: string) {
    // Simple hash function to convert string to a numeric value
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
        hash = str.charCodeAt(i) + ((hash << 5) - hash);
    }
    // Convert hash to hex color
    let color = '#';
    for (let i = 0; i < 3; i++) {
        const value = (hash >> (i * 8)) & 0xFF;
        color += ('00' + value.toString(16)).slice(-2);
    }
    return color;
}

@Component
export struct IssuerIcon {
    @Require @Prop issuer: string;
    @Prop iconSize: ResourceStr = '64vp';
    @Prop iconRadius: ResourceStr = '32vp';
    @Prop fontSize: number = 36;//fp

    capital = this.issuer.charAt(0).toUpperCase();

    build() {
        Shape() {
            Text(this.capital)
                .fontWeight(FontWeight.Bold)
                .fontSize(this.fontSize)
                .fontColor(0xFFFFFF)
                .height(this.iconSize).width(this.iconSize)
                .textAlign(TextAlign.Center)
        }
        .backgroundColor(stringToColorHex(this.issuer))
        .height(this.iconSize).width(this.iconSize)
        .borderRadius(this.iconRadius)
    }
}
