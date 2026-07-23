# eliza1966

由薯条猫修复还原的1966年聊天机器人伊莉莎（ELIZA）。

## 功能

- **规则模式**：经典1966原型，反射式日常闲聊
- **自定义模型模式**：支持任意 OpenAI 兼容 API（输入 URL 和 Key，自动获取可用模型列表）

## 使用方法

1. 安装 APK
2. 默认规则模式可直接聊天
3. 点击左上角头像图标打开模式切换
4. 选择"自定义模型"，输入 API 地址和 Key，获取模型列表
5. 选择模型后点击确认，自动切换到自定义模型模式

## 技术栈

- Android WebView
- 纯 HTML/CSS/JS 前端
- OpenAI 兼容 API 协议

## 构建

```bash
# 需要 Android SDK Build Tools 34
# 需要 JDK 17
bash build.sh
```

## License

MIT
