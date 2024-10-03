# Aigis

A lite alternative to [Aegis](https://github.com/beemdevelopment/Aegis) for HarmonyOS NEXT, with pure ArkTS implementation and no 3rd party dependencies.

### TODO
- [x] TOTP & HOTP Algorithm Implementation
- [ ] HUKS key storage

### References

- **Call Scan Kit**
    ```typescript
    // 定义扫码参数options
    let options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: true,
        enableAlbum: true
    };
    // 启动扫码，拉起扫码界面
    scanBarcode.startScanForResult(getContext(this), options,
        (error: BusinessError, result: scanBarcode.ScanResult) => {
        if (error) {
            hilog.error(0x0001, '[Scan CPSample]',
            `Failed to get ScanResult by callback with options. Code: ${error.code}, message: ${error.message}`);
            return;
        }
        hilog.info(0x0001, '[Scan CPSample]', `Succeeded in getting ScanResult by callback with options, result is ${JSON.stringify(result)}`);
        })
    ```

- **Set Window Privacy Mode** ([link](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-window-V5#setwindowprivacymode9))

- **Page Modal Transition - Bind Sheet** ([link](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-universal-attributes-sheet-transition-V5#bindsheet))
