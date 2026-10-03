# 常见动作真人教学验证清单

更新：2026-10-03。36 个可播放节选，对应 36 个不同动作模板；本批新增 12 个。不是候选视频数量。

## 怎么验证

用 Xcode 的 Debug 构建运行当前分支；如果 App 已经开着，完全退出后重开，再进入任意动作详情触发云端索引更新。当前正式商店版和 Release 构建不会播放 developmentOnly 节选。

1. 在动作库搜索下表中文名称；相近名称以动作 ID、器械和动图区分。
2. 打开详情，检查动图和真人教学是否为同一动作。
3. 播放教学并拖动进度，确认画面、声音与字幕正常。
4. 选择自己的视频，按片段说明的角度进行手动同屏对比。
5. 在训练计划添加同一个动作，确认进入同一详情并看到教学。没有匹配教学的动作仍保留动图，不伪造视频。

## 云端视频

视频文件保存在腾讯云 CloudBase Hosting 背后的对象存储；映射索引是云端 catalog-v1.json，不是 NoSQL 数据库表，也不把视频二进制存进数据库或 App 包。App 只按需下载选中的短片段并缓存。部分片段是谭师指导学员或与凯圣王共创，不等于全由谭师本人做示范。

| 动作库名称 | ID | 时长 | 原视频节选 | 播放验证 |
|---|---|---:|---|---|
| 绳索下拉 | 0198 | 25s | [350–375s](https://www.douyin.com/video/7662562022056718449) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7662562022056718449-350-375.mp4) |
| 哑铃侧平举 | 0334 | 19s | [132–151s](https://www.douyin.com/video/7666644718105452666) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7666644718105452666-132-151.mp4) |
| 船长椅椅直举腿 | 2963 | 20s | [254–274s](https://www.douyin.com/video/7657365167379023973) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7657365167379023973-254-274.mp4) |
| 卷腹地面 | 0274 | 25s | [452–477s](https://www.douyin.com/video/7657365167379023973) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7657365167379023973-452-477.mp4) |
| 健腹轮滚动 | 0857 | 21s | [782–803s](https://www.douyin.com/video/7657365167379023973) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7657365167379023973-782-803.mp4) |
| 绳索后踢臂屈伸 | 0860 | 23s | [316–339s](https://www.douyin.com/video/7648931004442846193) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7648931004442846193-316-339.mp4) |
| EZ杠仰卧窄握三头肌臂屈伸颈后 | 1748 | 20s | [724–744s](https://www.douyin.com/video/7648931004442846193) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7648931004442846193-724-744.mp4) |
| EZ杠弯举 | 0447 | 24s | [686–710s](https://www.douyin.com/video/7658495365934683493) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7658495365934683493-686-710.mp4) |
| 绳索反握下拉 | 0245 | 20s | [541–561s](https://www.douyin.com/video/7662562022056718449) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7662562022056718449-541-561.mp4) |
| 哑铃卧推 | 0289 | 25s | [1240–1265s](https://www.douyin.com/video/7668880941976944817) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7668880941976944817-1240-1265.mp4) |
| 哑铃坐姿三头肌臂屈伸 | 2188 | 21s | [1037–1058s](https://www.douyin.com/video/7614695798211440613) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7614695798211440613-1037-1058.mp4) |
| 胸部臂屈伸 | 0251 | 16s | [806–822s](https://www.douyin.com/video/7614695798211440613) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7614695798211440613-806-822.mp4) |
| 哑铃高脚杯深蹲 | 1760 | 27s | [2173–2200s](https://www.douyin.com/video/7629718942222650670) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7629718942222650670-2173-2200.mp4) |
| 杠铃罗马尼亚硬拉 | 0085 | 23s | [2815–2838s](https://www.douyin.com/video/7629718942222650670) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7629718942222650670-2815-2838.mp4) |
| 背屈伸 | 0489 | 22s | [3163–3185s](https://www.douyin.com/video/7629718942222650670) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7629718942222650670-3163-3185.mp4) |
| 哑铃罗马尼亚硬拉 | 1459 | 20s | [344–364s](https://www.douyin.com/video/7671852814386030521) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7671852814386030521-344-364.mp4) |
| 器械坐姿飞鸟 | 0596 | 17s | [414–431s](https://www.douyin.com/video/7661923214516256369) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7661923214516256369-414-431.mp4) |
| 器械坐姿反向飞鸟双杠握 | 0601 | 15.5s | [803–818.5s](https://www.douyin.com/video/7661923214516256369) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7661923214516256369-803-818.5.mp4) |
| 哑铃单腿分腿蹲 | 0410 | 24s | [1710–1734s](https://www.douyin.com/video/7655982129109198321) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7655982129109198321-1710-1734.mp4) |
| 器械俯卧腿弯举 | 0586 | 20s | [3044–3064s](https://www.douyin.com/video/7655982129109198321) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7655982129109198321-3044-3064.mp4) |
| 绳索直背部坐姿划船 | 0239 | 20s | [996–1016s](https://www.douyin.com/video/7674643042243064997) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7674643042243064997-996-1016.mp4) |
| 哑铃坐姿肩上推举 | 0405 | 15.8s | [1295–1310.8s](https://www.douyin.com/video/7651943506576442225) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7651943506576442225-1295-1310.8.mp4) |
| 哑铃前平举2 | 0309 | 20s | [2100–2120s](https://www.douyin.com/video/7651943506576442225) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7651943506576442225-2100-2120.mp4) |
| 哑铃上斜卧推举 | 0314 | 20s | [2641–2661s](https://www.douyin.com/video/7625479021379194118) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7625479021379194118-2641-2661.mp4) |

### 本批新增 12 个

| 动作库名称 | ID | 时长 | 原视频节选 | 播放验证 |
|---|---|---:|---|---|
| 杠铃卧推 | 0025 | 18s | [578–596s](https://www.douyin.com/video/7625479021379194118) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7625479021379194118-578-596.mp4) |
| 哑铃上斜二头肌弯举 | 0315 | 20s | [1418–1438s](https://www.douyin.com/video/7648931004442846193) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7648931004442846193-1418-1438.mp4) |
| 哑铃后弓步 | 0381 | 15s | [485–500s](https://www.douyin.com/video/7616718842858024121) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7616718842858024121-485-500.mp4) |
| 哑铃站姿三头肌臂屈伸 | 0430 | 15s | [620–635s](https://www.douyin.com/video/7617450016814465785) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7617450016814465785-620-635.mp4) |
| 哑铃后飞鸟 | 0378 | 11s | [255–266s](https://www.douyin.com/video/7617450016814465785) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7617450016814465785-255-266.mp4) |
| 哑铃交替二头肌弯举 | 0285 | 11s | [588–599s](https://www.douyin.com/video/7617450016814465785) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7617450016814465785-588-599.mp4) |
| 哑铃俯身划船 | 0293 | 15s | [898–913s](https://www.douyin.com/video/7615846680018354609) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7615846680018354609-898-913.mp4) |
| 弹力带辅助引体向上 | 0970 | 16s | [712–728s](https://www.douyin.com/video/7615846680018354609) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7615846680018354609-712-728.mp4) |
| 绳索站姿飞鸟 | 0227 | 14s | [237–251s](https://www.douyin.com/video/7610712695184852603) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7610712695184852603-237-251.mp4) |
| 器械上斜胸推2 | 1479 | 15s | [805–820s](https://www.douyin.com/video/7610712695184852603) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7610712695184852603-805-820.mp4) |
| 杠铃站姿窄握站姿推举 | 1456 | 12s | [991–1003s](https://www.douyin.com/video/7610712695184852603) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7610712695184852603-991-1003.mp4) |
| 绳索过头三头肌臂屈伸绳配件 | 0194 | 15s | [1088–1103s](https://www.douyin.com/video/7610712695184852603) | [云端 MP4](https://fitgenius-d0ghm1rz21cef6594-1441969311.tcloudbaseapp.com/exercise-tutorials/development-media/7610712695184852603-1088-1103.mp4) |

重点验收：0970 视频采用双脚踩弹力带，动图采用套膝，属于同一辅助引体的支撑位置变式；拍摄和同屏比较按视频的带位，不混两种方法。0194 / 0378 / 0430 的原双语文字与动图不一致，本批已纠正为低位滑轮、坐姿反飞鸟、双手单哑铃站姿屈伸，需要用新 Debug 构建检查说明。

## 资产校验

本地每个节选均核对 H.264 视频 + AAC 音频、时长、20 MB 上限。下面的 SHA-256 用于与云端下载逐个比较；上传通过不代替真机播放和内容验收。

| ID | 字节数 | SHA-256 |
|---|---:|---|
| 0198 | 4820531 | c865fbcb888da6a427c010aa910f9e512222e20e8c8e8cb1c82092e0e4d91daa |
| 0334 | 5305447 | 26c08709325748a3b80c20a6b9bce7dc88933ec4bdb442c4fc1a20f2411c489f |
| 2963 | 3365912 | 74245b8bb88cff42b6015cc60d0f6eaf7c65932b86fcdeac0baa797167ad7415 |
| 0274 | 3998810 | a7225ec9bf5756762715cbc0b9bca6c3ef73c8da33feb27727cf56359e178ae9 |
| 0857 | 5048472 | e564a1808b10b22f94a860b5df05e49af65349992cdcd8e9a180529c2410daf5 |
| 0860 | 3352331 | 665ad637fa6b97359efdaabe813f53eee366a06d2a5a6332d839ff3ffb760890 |
| 1748 | 2952246 | 57a30142130b07db854fd76ce401abc19c7a4545e4d5a9687538e8c3fb265765 |
| 0447 | 4459238 | 5b5d3316c089edb4dcce3648580c29aa5e36379c1a699101161d042f4efeaa95 |
| 0245 | 5283932 | e00066c3526a755e598c406fa46faf7f96b0aa98c172dd26e43c523663940770 |
| 0289 | 3091582 | b8aa0f4300b71aeaf7e0e18574eaca564a409b3a84adb1c69a1336e58fa45f28 |
| 2188 | 1966013 | 1d7e29de130afab425242c8972ab38f01c76d0a77fcfebae019d074be659288b |
| 0251 | 1881584 | 1ce0b7b9b26b979220ac49c31237b3b58800f1a70d1e275f455e555971cadc41 |
| 1760 | 4471189 | f7726c4ae48d22a12f0d4b08e0f991a8416d651c1c6fc08a82033c8a537c6fef |
| 0085 | 3896268 | b79b3da2e98b98f508287c7be977bc518c466567b76f313ca8a60163f9aba047 |
| 0489 | 3508093 | 1262f0835bda0ae3e0aa089b1bd8d01ee8f58f3e3522817d783df1b61ea26026 |
| 1459 | 4098260 | d78ca01175b7fd2a895aa132d994436aca0548a686e1d9882580771614895f05 |
| 0596 | 2181286 | 6de7be1ca60bb3837c758337a5cbc8a259541e52f76a4102224658f5f225e6e1 |
| 0601 | 2170021 | 1ff0ff39042549276325d4b3eba37fca3a054e07afa9c70a609939a17422e958 |
| 0410 | 6062588 | c1cf01e48cf09bb4eff8f17b5716d3ccdacba762bd99f45e369426fc43887033 |
| 0586 | 6172553 | 34b6c835ca96b12dc8252cc4411df1e697d87626ce1224364b93b81a19df25fe |
| 0239 | 3788243 | 5e25557fe8c2c22676ec5fe4d8a4de6f184a1335e01e375c4f956b1e16c3a970 |
| 0405 | 2640838 | 9db21685f70927d108799fb7856ade93dc227c110b49a10f84ec8185684343e3 |
| 0309 | 3884522 | 217993263a17dc380b0046a4028263bc4a91bc92dd827b15edc90d988523fc08 |
| 0314 | 6211518 | c5aebaae3580ca126f6f2e1aac8960242c0fef75a8dccd13e7e548c995aa5b99 |
| 0025 | 5215721 | 912baaf583f212a11c9f050b692f0d4ca78a0e4f7593b77427ce99bef04df030 |
| 0194 | 2196015 | fb9c19c18e5345980d80d66df782a8c045aa223f46832a0ff0d9c1c7b5b86c04 |
| 0227 | 2865498 | 2f8cf9753da1551d01195573799d72fc959454e63586fed6768526d3cee819cb |
| 0285 | 1596232 | 0e5f32bd601bfe8cf6ce64a3f70a189345ef16c14fafd3d38d0d6e4835b22331 |
| 0293 | 2299184 | 2eb64dd741ce32180f0b311a837c181727c7f5dab4459a2f90a7e37a6c38e9dd |
| 0315 | 3582052 | 5c1fde1b2f2b8c00434efc4d97094273dfb9d41a6b86aba79e62d31f24742ce2 |
| 0378 | 1753636 | ca5e655f4f3850c9e1fdaf2bbdcf53ec27018c6fec6c4af7247971546ab5cbcc |
| 0381 | 2298256 | 83cf98a4a6dcc60a616bd17b5aa2c94cd4e9122807167b201741297cb47092b0 |
| 0430 | 2125163 | a382a7a4827447025d441724c2a37fe71177940a0d6393ca6a9e227d0f68c63f |
| 0970 | 2703432 | 3db9f323eabe7f959d69ffb1dde9fb1c43434e25bcda8bdf67b43bd10149dbe4 |
| 1456 | 1515508 | e17118b9358e4e0d570720db7c9d9902e238f9792e206b557570637283f5a527 |
| 1479 | 3508952 | a956bd1c4fdbf425a4981ef0801656348c9d3f2be4790ffc21fd9c14bb45f09f |
