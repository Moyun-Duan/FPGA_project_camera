# 图像清晰度、边缘检测与目标高亮实验评估

本实验分支：

```text
experiment/image-quality-edge-recognition
```

目标是在不降低当前 320x240 采集帧率、不引入外部存储、不改变 VGA 640x480 显示结构的前提下，试验低成本图像质量和边缘显示改进。

## 1. 灰度图清晰度路径

当前稳定链路使用 OV7670 YUV422，只取 Y 亮度字节。此前代码为了复用 `rgb565_to_gray`，先把 Y 亮度压成 RGB565 灰度，再重新计算灰度。这个过程会丢失部分低位亮度信息。

本分支改动：

```text
ov7670_capture 增加 LUMA_OUTPUT 参数
pixel_filter_pipeline 增加 INPUT_LUMA 参数
vision_top 启用 CAMERA_LUMA_OUTPUT=1
```

效果：

```text
Y 字节以 8-bit 原始亮度进入后级滤波
避免 Y -> RGB565 -> gray 的量化损失
不增加像素处理周期，不降低帧率
```

预期收益：

```text
灰度细节和边缘梯度更稳定
mode 00/01 的灰阶过渡保留更多低位信息
Sobel 阈值输入更接近摄像头真实亮度
```

## 2. `SW1,SW0 = 10` 边缘检测优化

原 `canny_pipeline` 实际是 Sobel 幅值阈值检测，并且存在坐标/valid 与梯度结果流水线延迟不匹配的问题。结果会导致边缘像素写入帧缓存的位置错位，轮廓线更容易发虚。

本分支改动：

```text
1. 重新整理 canny_pipeline 为显式 3 级 Sobel 流水线。
2. 坐标、valid、magnitude、is_edge 同步延迟输出。
3. 使用参数 HIGH_THRESHOLD/SOBEL_THRESHOLD，不再使用模块内部固定阈值 180。
4. Sobel 幅值恢复为原始 mag_sum 饱和到 8-bit，不再右移缩放。
5. 默认阈值降为 SOBEL_LOW_THRESHOLD=24、SOBEL_THRESHOLD=64，优先保证轮廓完整。
6. mode 10 弱边缘从浅灰 160 改为更清晰的深灰 96。
7. 修正 mode 11 中漫画灰阶与 Sobel 输出的延迟对齐。
```

预期收益：

```text
边缘线位置更准确
强/弱边缘分层更可调
阈值从顶层参数统一控制
不会降低吞吐率，仍是流式像素处理
```

限制：

```text
当前仍不是完整 Canny。
完整 Canny 的非极大值抑制和滞后阈值需要额外梯度方向/邻域幅值缓存，资源和验证成本更高。
```

### 2.1 上板反馈后的修正

上一版实验中，`SW1,SW0=10` 的边缘明显少于旧版本。原因是 Sobel 幅值被右移两位后仍使用 128 阈值，等效要求原始梯度超过约 512，很多真实边缘被过滤掉。

本轮修正后：

```text
Sobel 幅值：恢复原始幅值饱和输出
强边缘阈值：128 -> 64
弱边缘阈值：48 -> 24
mode 10 弱边缘亮度：160 -> 96
```

当前优先级：

```text
先保证 mode 10 边缘尽可能完整
mode 11 依赖同一边缘结果，随 mode 10 一起恢复轮廓清晰度
红色轮廓识别暂不进入顶层显示路径
```

### 2.2 黑点/条纹噪声修正

上板反馈中，mode 10 边缘恢复后，背景出现明显黑点和短条纹噪声。继续单纯提高 Sobel 阈值会重新丢失轮廓，因此本轮改为边缘前后处理：

```text
1. Sobel 前做 4 邻域脉冲噪声钳位。
   如果中心像素比上/下/左/右都暗很多或亮很多，就用四邻域平均替代。
   默认 IMPULSE_DELTA=48。

2. Sobel 输入改为脉冲钳位后的亮度流。
   这样孤立坏点不会被高斯平滑扩散成一圈小边缘。

3. Sobel 后增加 3x3 边缘连通性过滤。
   强边缘默认需要 strong_support>=3 或 soft_support>=4。
   弱边缘默认需要 soft_support>=4。
```

目的：

```text
去掉孤立黑点和很短的毛刺边缘
保留连续的人体/物体轮廓线
不回退到简单高阈值导致边缘缺失
```

当前顶层参数：

```text
SOBEL_LOW_THRESHOLD      = 24
SOBEL_THRESHOLD          = 64
IMPULSE_DELTA            = 40
EDGE_STRONG_MIN_SUPPORT  = 5
EDGE_SOFT_MIN_SUPPORT    = 6
EDGE_FINAL_STRONG_MIN_SUPPORT = 5
EDGE_FINAL_SOFT_MIN_SUPPORT   = 6
RED_EDGE_EXPERIMENT      = 0
```

上板继续反馈后，确认边缘位置基本可接受，但短黑点/短条纹仍明显。因此当前版本进一步修改：

```text
1. 脉冲噪声替换不再使用四邻域平均，而是使用背景估计：
   暗噪声 -> direct_max
   亮噪声 -> direct_min

2. 判定短毛刺时不只看方向成对支撑，而是看 8 邻域同类像素数量：
   同类邻居 < 3 时按噪声替换。

3. 边缘图支撑过滤增加第二级 final window。
   第一级和第二级都使用 5/6 支撑阈值，优先压短条纹。
```

## 3. 简单图像识别/红色轮廓实验

在 FPGA 当前资源和项目时间约束下，不建议直接实现“真正的人体识别”。CNN、HOG/SVM 或模板匹配都需要更多片上存储、乘加资源和训练/标定流程。

本分支保留一个可综合的低成本候选高亮作为后续实验：

```text
1. 持续统计上一帧强边缘点的包围盒。
2. 如果包围盒满足竖向、尺寸足够、边缘数量足够，则认为是 person-like candidate。
3. 下一帧在候选包围盒内，把强边缘标记为红色。
4. 其余边缘仍保持 mode 10 的黑色/灰色线条。
```

模块级实现方式：

```text
pixel_filter_pipeline 输出 out_red_edge
RED_EDGE_ENABLE=1 时才启用候选区域标记
tb_person_edge_highlight 只验证模块级可行性
vision_top 当前 RED_EDGE_EXPERIMENT=0，顶层默认关闭
顶层帧缓存保持 8 bit，不输出红色轮廓
```

风险：

```text
这不是严格人体识别，只是人形/竖向目标候选检测。
直立物体、门框、桌腿等也可能被误标。
当前算法使用上一帧统计结果，因此红色轮廓有一帧决策延迟。
当前上板验证阶段不启用它，避免影响 mode 10/11 边缘调试。
```

## 4. 验证结果

Icarus Verilog 回归：

```text
PASS: tb_ov7670_capture
PASS: tb_canny_threshold
PASS: tb_pixel_filter_pipeline
PASS: tb_edge_noise_rejection
PASS: tb_edge_short_streak_rejection
PASS: tb_person_edge_highlight
All offline simulations passed.
```

新增测试：

```text
tb_canny_threshold
tb_edge_noise_rejection
tb_edge_short_streak_rejection
tb_person_edge_highlight
```

测试内容：

```text
tb_canny_threshold 验证 24 级亮度差的竖直边缘能被阈值检测出来。
tb_edge_noise_rejection 验证孤立黑点不会产生大量黑色边缘噪声。
tb_edge_short_streak_rejection 验证 3 像素短条纹不会产生大量黑色边缘噪声。
第一帧只收集竖向边缘统计
第二帧根据上一帧候选包围盒输出红色边缘标记
当前测试输出 red edges=42
```

Vivado 2017.4 非工程综合：

```text
synth_design -top vision_top -part xc7a35tcsg324-1
结果：0 errors, 0 critical warnings
```

报告位置：

```text
vivado_reports/nonproject_post_synth_utilization.rpt
vivado_reports/nonproject_post_synth_utilization_hier.rpt
```

## 5. 后续实物调试建议

先烧录本分支 bitstream，按顺序观察：

```text
1. mode 00 灰度图是否比旧版本更平滑/更清楚。
2. mode 01 锐化灰度是否增强细节但不过度放大噪声。
3. mode 10 黑色边缘位置是否更贴合真实轮廓。
4. 暂时不要看红色轮廓，当前顶层默认关闭红色识别。
```

若 mode 10 边缘仍然太少，优先继续降低：

```text
SOBEL_THRESHOLD: 64 -> 48
SOBEL_LOW_THRESHOLD: 24 -> 16
```

若 mode 10 噪声边缘太多，优先提高：

```text
EDGE_STRONG_MIN_SUPPORT: 5 -> 6
EDGE_SOFT_MIN_SUPPORT: 6 -> 7
EDGE_FINAL_STRONG_MIN_SUPPORT: 5 -> 6
EDGE_FINAL_SOFT_MIN_SUPPORT: 6 -> 7
```

若提高支撑后轮廓断裂，再优先回退：

```text
EDGE_FINAL_STRONG_MIN_SUPPORT: 5 -> 4
EDGE_FINAL_SOFT_MIN_SUPPORT: 6 -> 5
EDGE_STRONG_MIN_SUPPORT: 5 -> 4
EDGE_SOFT_MIN_SUPPORT: 6 -> 5
```

若整体噪声仍然偏多且轮廓足够完整，再考虑提高：

```text
SOBEL_THRESHOLD: 64 -> 80
SOBEL_LOW_THRESHOLD: 24 -> 32
```

等 mode 10/11 边缘稳定后，再启用红色轮廓实验。若红色误检过多，优先调：

```text
PERSON_MIN_EDGES
PERSON_MIN_WIDTH
PERSON_MIN_HEIGHT
PERSON_MAX_WIDTH
SOBEL_THRESHOLD
```

若边缘太少或人体不标红，优先降低：

```text
SOBEL_THRESHOLD
PERSON_MIN_EDGES
PERSON_MIN_HEIGHT
```

若噪声边缘太多，优先提高：

```text
SOBEL_THRESHOLD
SOBEL_LOW_THRESHOLD
PERSON_MIN_EDGES
```
