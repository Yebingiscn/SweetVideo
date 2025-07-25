<p align="center"><img src="./entry/src/main/resources/base/media/sweet_video.png" style="width: 128px; height: 128px;"  alt="logo"></p>
<div align="center">
    <h1>流心视频（枪獭播放器）</h1>
    <p>
        <a href="https://github.com/Yebingiscn/SweetVideo/releases/latest" style="text-decoration:none">
            <img src="https://img.shields.io/github/v/release/Yebingiscn/SweetVideo?display_name=release" alt="GitHub release (latest by date)"/>
        </a>
        <a href="https://img.shields.io/badge/OS-HarmonyOS Next-103fb6" style="text-decoration:none" >
            <img src="https://img.shields.io/badge/HarmonyOS-Next-103fb6" alt="HarmonyOS Version"/>
        </a>
        <a href="https://img.shields.io/badge/API-17-lightgreen" style="text-decoration:none" >
            <img src="https://img.shields.io/badge/API-17-lightgreen" alt="API Version"/>
        </a>
        <a href="https://img.shields.io/github/stars/Yebingiscn/SweetVideo?style=flat" style="text-decoration:none" >
            <img src="https://img.shields.io/github/stars/Yebingiscn/SweetVideo?style=flat" alt="GitHub all stars"/>
        </a>
        <a href="https://img.shields.io/badge/QQ-973792610-red" style="text-decoration:none" >
            <img src="https://img.shields.io/badge/QQ群-973792610-red" alt="QQ Group"/>
        </a>

 <a href="LICENSE" style="text-decoration:none" >
            <img src="https://img.shields.io/github/license/Yebingiscn/SweetVideo" alt="GitHub license"/>
        </a>
        <a href="https://img.shields.io/github/forks/Yebingiscn/SweetVideo" style="text-decoration:none" >
            <img src="https://img.shields.io/github/forks/Yebingiscn/SweetVideo" alt="GitHub fork"/>
        </a>
    </p>
</div>
<p align="center">一款运行在 HarmonyOS Next 上的精致、简约的原生视频播放器</p>
<p align="center">A slick, minimalist video player that runs on HarmonyOS Next</p>

## 流心视频（枪獭播放器）交流群

QQ群：973792610

## 欢迎加入流心视频（枪獭播放器）测试组

> 可以从华为应用商店收到内测提醒和更新

请加入 QQ 群获取最新测试链接

## 功能排期

- [ ] 对每个视频自定义跳转时间（完成全局设置，已过滤音频）
- [ ] FFMpeg播放器选集功能
- [ ] 完全的字幕功能支持(ASS、SRT)
- [ ] 视频标签（点击标签即可跳转该视频对应时间）

### 远期支持

- [ ] 播放器移植
- [ ] WebDAV 支持
- [ ] Emby 支持
- [ ] FTP 支持

## 简介

- 一款运行在 HarmonyOS Next 上精致、简约的视频（音乐）原生播放器，使用 ArkTS 语言开发，具有美观的设计和优雅的动画。
- 基于开源项目`流心视频` https://gitee.com/lqsxy/sweetvideo/tree/master
- 本应用根据原作者授权并基于 MIT 协议二次开发而来。

## 内置播放器

| 系统播放器(avplayer)         | FFMpeg播放器(ijkplayer) | 红薯播放器(REDPlayer)        |
|-------------------------|----------------------|-------------------------|
| 支持格式较少，不支持杜比/DTS 音轨     | 占用高，容易闪退             | 格式支持较少                  |
| 支持 HDR/Audio Vivid，流畅省电 | 支持格式丰富，支持rmvb格式      | 流畅播放 4K HDR 杜比 / DTS 视频 |

## 支持的视频 / 音乐格式

| 类型         | 格式列表                                                                                                  |
|------------|-------------------------------------------------------------------------------------------------------|
| 视频容器       | `mp4`, `flv`, `mkv`, `ts`, `mov`, `rmvb`, `wmv`, `avi`, `m4v`                                         |
| 音频编码（音乐格式） | `wav`, `mp3`, `flac`, `m4a`, `ape`, `aac`, `ogg`, `amr`, `aif`, `aiff` , `dts`, `wma`,  `dff`, `av3a` |

## 支持的字幕格式

| 类型   | 格式列表         |
|------|--------------|
| 字幕文件 | `srt`, `vtt` |

## 特别鸣谢 && 欢迎参与共建及须知

> 欢迎提交 PR，一起共同建设流心视频（枪獭播放器） \
> 提交 PR 请遵照以往提交格式，如`[fix]`是修复内容 `[update]`是优化内容 `[new]`是新增内容 \
> 如果提交中有没有解决的地方请注明

- 流心视频开源项目作者：鱼Salmon
- 图标、头图等素材：科蓝kl
- 记账本 R 作者：漫漫是我宝
- 测试视频提供：萧十一狼
- 折叠屏适配：微车游
- AloePlayer 作者：Aloereed
- kimufly

## 流心视频（枪獭播放器）由以下开源项目提供支持

- 播放器R
- 流心视频 https://gitee.com/lqsxy/sweetvideo/tree/master
- pinyin4js https://ohpm.openharmony.cn/#/cn/detail/@ohos%2Fpinyin4js
- ohos_ijkplayer https://gitee.com/openharmony-sig/ohos_ijkplayer/tree/master
- REDPlayer https://github.com/RTE-Dev/REDPlayer