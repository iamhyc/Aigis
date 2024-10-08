# Aigis

A lightweight alternative to [Aegis Authenticator](https://github.com/beemdevelopment/Aegis) for HarmonyOS NEXT, with pure ArkTS implementation and no 3rd party dependencies.

### TODO

**Release v0.2.0**:
- [ ] Item List Search by filter
- [ ] Item Drag to Sort
- [ ] Item Swipe Action: Edit / Removal
- [ ] Item Edit Page
  - (Scan) --> [Item Edit Page] --> Persist
- [ ] Better Icon Match
- [ ] Access Control with Authentication
  - Auto-lock when in background

**Release v0.3.0**:
- [ ] Settings Page Design
  - Disable Account Name Display / Only Show with duplicate issuers
  - Code Split Digits Option (2/3/4/'Even'/'None')
  - Set Password
  - Password Challenge Notification Period
- [ ] Password to master key via PBKDF2
  - master key stored in HUKS for AES *encrypt & examine* purpose only
  - so, cannot change password, or the secrets cannot export any more
- [ ] HUKS for MAC Key storage (cannot export)
  - `SecretStore` only used for export, cause no *decrypt* purpose function provided
- [ ] Bulky Export Support (in Aegis format)
- [ ] Bulky Import Support (Aegis only, Encrypted only)
  - support import password (master key) at the same time

**Release v0.5.0**:
- [ ] Allow to change password
- [ ] Password Challenge Design

### References

- [Aegis Authenticator - ctypto/otp](https://github.com/beemdevelopment/Aegis/tree/master/app/src/main/java/com/beemdevelopment/aegis/crypto/otp)

- [Github - pyotp](https://github.com/pyauth/pyotp.git)

- HarmonyOS NEXT 官方文档
  
  - [文档中心 - 元服务开发指南](https://developer.huawei.com/consumer/cn/doc/atomic-guides-V5/atomic-service-V5)

  - [文档中心 - 设计指南](https://developer.huawei.com/consumer/cn/doc/design-guides/design-concepts-0000001795698445)

  - [文档中心 - 开发指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/application-dev-guide-V5?catalogVersion=V5)

  - [文档中心 - API参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/development-intro-api-V5?catalogVersion=V5)


- **Page Modal Transition - Bind Sheet** ([link](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-universal-attributes-sheet-transition-V5#bindsheet))
