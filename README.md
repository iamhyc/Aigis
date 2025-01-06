# 下架公告 / Take Down Notice

**当前（2025-01-06 09：55：00 GMT+0800）Aigis已成功下架，该项目现在存档，开发无限期停止。**

> [!NOTE]
>
> 为什么会发生这种事：[[OPEN] 今天的AGC审核人员依然趾高气昂 / [OPEN] Today's AGC auditors are still high and mighty](https://github.com/iamhyc/Aigis/issues/30)

于2025年1月4日零时，Aigis 已发起全网下架请求，即将终止通过 HarmonyOS AG 进行应用分发。v1.0.0 版本已终止上架流程，当前AG中上架的最新版本为 v0.8.0。

请尽快将您的数据迁移至其他软件。对于鸿蒙NEXT系统，只推荐开源的“[OTP令牌](https://github.com/SolidFaker/ohtotptoken)”，不推荐其他闭源/有网络权限/有抄袭嫌疑的 2FA/MFA 软件，包括但不限于：一日MFA，星御TOTP验证器，Dove验证器，手机令牌，Ezi身份验证器 等。

### 数据迁移

- **使用AG版本**（v0.8.0）

  - **未设置主密钥**

    请在条目编辑页面（条目上右滑），通过 分享链接 或 分享二维码，逐个条目导出到其他支持的软件。

  - **已设置主密钥**

    1. 请先通过 Aigis“设置 > 导出到文件”，导出“Aigis (.JSON)”格式的备份文件；
    2. 在系统设置中，通过“应用和元服务 > 元服务 Tab”，找到 Aigis 并点进去“移除元服务”以卸载Aigis（数据将会被完全清除）；
    3. 在AG中，搜索 Aigis 并重新安装Aigis；
    4. 通过 Aigis“设置 > 从文件导入”，导入 步骤1 中备份的文件，注意不要勾选“同时设置为主密钥”；
    5. 参考“未设置主密钥”的情形，逐个导出条目到其他支持软件。

- **使用GitHub版本**（v1.0.0）

  1. 请通过自签名方式安装 [Release v1.0.0](https://github.com/iamhyc/Aigis/releases) 中的 "entry-default-unsigned.hap" ；
  2. 通过 Aigis“设置 > 导出到文件”，选择导出格式“Aegis 身份验证器”（需输入 主密钥 验证，用于加密备份文件）；
  3. 在安卓手机（或卓易通）上安装 [Aegis Authenticator](https://github.com/beemdevelopment/Aegis)，导入步骤2中备份的JSON文件。

