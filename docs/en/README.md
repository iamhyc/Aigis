# Aigis Authenticator

> [!NOTE]
> Our meta-service is now available on the APP Gallery, please search for "Aigis" to use!

A lightweight alternative to [Aegis Authenticator](https://github.com/beemdevelopment/Aegis) for HarmonyOS NEXT, with pure ArkTS implementation and no 3rd party dependencies.

<p float="left">
  	<img height="400px" alt="screenshot_main_page_light" src="./images/screenshot_main_page_light.jpg" />
  	&nbsp;&nbsp;
  	<img height="400px" alt="screenshot_edit_page_light" src="./images/screenshot_edit_page_light.jpg" />
  	&nbsp;&nbsp;
    <img height="400px" alt="screenshot_add_card" src="./images/screenshot_add_card.jpg" />
  	&nbsp;&nbsp;
  	<img height="400px" alt="screenshot_settings_page_light" src="./images/screenshot_settings_page_light.jpg" />
</p>


### Security Design (for version `>=2.0.0`)

```mermaid
flowchart LR

Dst1[["OTP Tokens"]]
Dst2[("Items & Settings")]
Dst4[["APP Pages"]]

Src0(["Biometric/PIN (ATL1)"])

Src1(["Biometric (ATL3)"])

Src2(["Master Password"])
Src2a["dec_master_key"]
Via2[("Encrypted Secrets<br/>(AES256-GCM)")]
Src2b["enc_master_key"]

subgraph "User Input"
Src0
Src1
Src2
end

subgraph "HUKS (TEE)"
Src2a
Src2b
end

subgraph "APP Sandbox"
Via2
Dst2
end

subgraph "Frontend"
Dst1
Dst4
end

Src1--Authenticate-->Src2a
Src2--PBKDF2/AES256-->Src2a--decrypt-->Via2--compute-->Dst1
Src2--PBKDF2/AES256-->Src2b--encrypt-->Via2

Src0--"Authenticate"-->Dst2--display-->Dst4
```

**Fallback Security Design**: If ATL3 is invalidated for any reason, the password will be prompted to decrypt the "Encrypted Secrets", and then re-import `dec_master_key` with no auth. If ATL1 is invalidated for any reason, the APP will be inaccessible until reinstalled.

### Roadmap

Please refer to the pinned issue [Aigis Roadmap](https://github.com/iamhyc/Aigis/issues/28)

### Contribution

> TODO

### References

- [Aegis Authenticator - ctypto/otp](https://github.com/beemdevelopment/Aegis/tree/master/app/src/main/java/com/beemdevelopment/aegis/crypto/otp)

- [Aegis Authenticator - docs/decrypt.py](https://github.com/beemdevelopment/Aegis/blob/master/docs/decrypt.py)
- [Github - pyotp](https://github.com/pyauth/pyotp.git)

- HarmonyOS NEXT Official Documentation
  
  - [文档中心 - 元服务开发指南](https://developer.huawei.com/consumer/cn/doc/atomic-guides-V5/atomic-service-V5)

  - [文档中心 - 设计指南](https://developer.huawei.com/consumer/cn/doc/design-guides/design-concepts-0000001795698445)

  - [文档中心 - 开发指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/application-dev-guide-V5?catalogVersion=V5)

  - [文档中心 - API参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/development-intro-api-V5?catalogVersion=V5)
