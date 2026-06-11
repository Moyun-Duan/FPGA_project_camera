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
4. Sobel 幅值按 mag_sum[12:2] 缩放到 8-bit，避免强边缘过早全部饱和。
5. 修正 mode 11 中漫画灰阶与 Sobel 输出的延迟对齐。
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

## 3. 简单图像识别/红色轮廓实验

在 FPGA 当前资源和项目时间约束下，不建议直接实现“真正的人体识别”。CNN、HOG/SVM 或模板匹配都需要更多片上存储、乘加资源和训练/标定流程。

本分支先实现一个可综合的低成本候选高亮：

```text
1. 持续统计上一帧强边缘点的包围盒。
2. 如果包围盒满足竖向、尺寸足够、边缘数量足够，则认为是 person-like candidate。
3. 下一帧在候选包围盒内，把强边缘标记为红色。
4. 其余边缘仍保持 mode 10 的黑色/灰色线条。
```

实现方式：

```text
pixel_filter_pipeline 输出 out_red_edge
vision_top 将帧缓存从 8 bit 扩展到 9 bit
bit[7:0] = 原灰度/边缘像素
bit[8]   = 红色轮廓标记
VGA 输出在 mode 10 中把该标记显示为红色
```

风险：

```text
这不是严格人体识别，只是人形/竖向目标候选检测。
直立物体、门框、桌腿等也可能被误标。
当前算法使用上一帧统计结果，因此红色轮廓有一帧决策延迟。
```

## 4. 验证结果

Icarus Verilog 回归：

```text
PASS: tb_ov7670_capture
PASS: tb_pixel_filter_pipeline
PASS: tb_person_edge_highlight
All offline simulations passed.
```

新增测试：

```text
tb_person_edge_highlight
```

测试内容：

```text
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
4. 画面中出现竖向人体/人形目标时，第二帧后是否出现红色轮廓。
```

若红色误检过多，优先调：

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
