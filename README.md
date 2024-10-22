# Aigis

> [!CAUTION]
> 使用当前 测试版本（≤v0.2.2） 升级5.0系统，会导致令牌数据全部丢失！！！
> 请关注[相关讨论](https://github.com/iamhyc/Aigis/issues/12)，对于已经造成的数据丢失，深表歉意！
> 
> 为了避免此类事情再次发生，10月25日前预计更新含有 密钥加密导出 特性的版本，其他特性及修正暂时推迟。

A lightweight alternative to [Aegis Authenticator](https://github.com/beemdevelopment/Aegis) for HarmonyOS NEXT, with pure ArkTS implementation and no 3rd party dependencies.

<p float="left">
  <img height="500px" alt="screenshot_light" src="./docs/images/screenshot_light.jpg" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img height="500px" alt="screenshot_dark" src="./docs/images/screenshot_dark.jpg" />
</p>

### TODO

**Release v0.2.3**:
- [ ] Bulky Export Support (in Aegis format)


**Release v0.3.0**:
- [ ] Settings Page Design
  - Disable Account Name Display / Only Show with duplicate issuers
  - Code Split Digits Option (2/3/4/'Even'/'None')
  - Set Password
  - Password Challenge Notification Period
- [ ] Access Control with Authentication
  - Auto-lock when in background
- [ ] Password to master key via PBKDF2
  - master key stored in HUKS for AES *encrypt & examine* purpose only
  - so, cannot change password, or the secrets cannot export any more
- [ ] HUKS for MAC Key storage (cannot export)
  - `SecretStore` only used for export, cause no *decrypt* purpose function provided
- [ ] Bulky Import Support (Aegis only, Encrypted only)
  - support import password (master key) at the same time

**Release v0.5.0**:
- [ ] Allow to change password
- [ ] Password Challenge Design
- [ ] Better Icon Match

**Release v1.0.0**
- [ ] All test pass

### References

- [Aegis Authenticator - ctypto/otp](https://github.com/beemdevelopment/Aegis/tree/master/app/src/main/java/com/beemdevelopment/aegis/crypto/otp)

- [Github - pyotp](https://github.com/pyauth/pyotp.git)

- HarmonyOS NEXT 官方文档
  
  - [文档中心 - 元服务开发指南](https://developer.huawei.com/consumer/cn/doc/atomic-guides-V5/atomic-service-V5)

  - [文档中心 - 设计指南](https://developer.huawei.com/consumer/cn/doc/design-guides/design-concepts-0000001795698445)

  - [文档中心 - 开发指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/application-dev-guide-V5?catalogVersion=V5)

  - [文档中心 - API参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/development-intro-api-V5?catalogVersion=V5)
