# 摄像头图像质量调试与优化记录

本文档记录当前实物图像现象、判断依据和本轮 RTL 优化。适用于 FPGA + VGA + OV7670 已经能显示画面，但图像噪声较重、颜色偏黄、模式差异不明显的阶段。

## 1. 当前现象

用户实物测试中已经能看到摄像头画面轮廓，说明：

```text
OV7670 至少已经有数据输出
cam_pclk / href / vsync / data 基本进入 FPGA
VGA 输出链路正常
帧缓存和显示读出基本工作
```

观察到的问题：

```text
1. 画面噪声重，细节不清晰。
2. 画面整体偏黄。
3. 拨动 mode_sw 后，四种模式肉眼区别不明显。
```

## 2. 优先判断

这些现象不优先判断为 VGA 问题，因为 VGA-only 已经显示了彩条、灰度、棋盘格和边框中心线。

更可能的原因：

```text
1. OV7670 并行数据线通过杜邦线连接，PCLK 较高时容易出现采样噪声。
2. OV7670 输出格式、RGB565 字节顺序或 D0-D7 顺序仍可能不完全匹配。
3. 当前 Sobel 阈值和输出形式对噪声敏感，导致不同模式看起来接近。
4. 摄像头自动曝光/自动白平衡尚未稳定，画面色调可能突变。
5. 如果完整工程中灰度输出仍明显偏黄，需要用新增模式标识检查 VGA 蓝色通道是否仍正常。
```

## 3. 本轮 RTL 修改

### 3.1 摄像头 XCLK 固定为 25 MHz

`rtl/vision_top.v` 中摄像头 `cam_xclk` 已固定为 25 MHz：

```text
pix_clk  = clk_100m / 4  = 25 MHz，用于 VGA
cam_xclk = clk_100m / 4  = 25 MHz
```

依据：

```text
实测 25 MHz 不花屏，拖动更平滑，清晰度略有提升。
12.5 MHz 已用于早期 bring-up，目前不再作为默认实物演示配置。
```

### 3.2 mode_sw 跨时钟同步

`mode_sw[1:0]` 现在分别同步到：

```text
cam_pclk 域：用于图像处理模式选择
pix_clk 域：用于屏幕叠加模式标识
```

目的：

```text
避免拨码开关直接跨时钟域进入处理逻辑。
```

### 3.3 模式标识叠加

完整工程 VGA 输出左上角和边框新增模式颜色标识：

| `mode_sw[1:0]` | 左上角/边框颜色 | 图像模式 |
|---|---|---|
| `00` | 蓝色 | 灰度图 |
| `01` | 绿色 | 锐化灰度图 |
| `10` | 红色 | 连续 Sobel 强度图 |
| `11` | 白色 | 平滑灰度 + 黑色边缘叠加 |

左上角还有 1 到 3 条竖条编码：

```text
00: 1 条
01: 2 条
10: 2 条，其中第三位置亮
11: 3 条
```

用途：

```text
1. 确认拨码开关是否真的被工程读到。
2. 确认当前烧录的是新 bitstream。
3. 检查 VGA R/G/B 通道在完整工程中是否仍正常。
```

如果 `mode_sw=00` 时左上角蓝色标识不是蓝色，应优先检查 VGA 蓝色通道或当前 bitstream 是否正确。

### 3.4 Sobel 输出增强

`rtl/pixel_filter_pipeline.v` 中：

```text
Sobel 高阈值默认 128
Sobel 低阈值默认 48
mode 10 输出连续 Sobel 强度图，低于低阈值的弱响应置黑
mode 11 输出平滑灰度 + 黑色边缘叠加，保留场景上下文
```

目的：

```text
避免纯二值边缘图过硬、过黑或过白。
用 mode 10 观察梯度强度，用 mode 11 观察边缘在原图中的位置。
```

## 4. 重新生成 bitstream

修改后需要重新运行完整工程：

```tcl
reset_run synth_vision_top
reset_run impl_vision_top
launch_runs synth_vision_top -jobs 4
wait_on_run synth_vision_top
launch_runs impl_vision_top -to_step write_bitstream -jobs 4
wait_on_run impl_vision_top
```

bitstream 通常在：

```text
vivado_build/fpga_vision_system.runs/impl_vision_top/vision_top.bit
```

烧录后先看左上角/边框模式标识是否随 `SW0/SW1` 变化。

## 5. 烧录后判断顺序

### 5.1 先判断拨码是否生效

拨动 `SW0/SW1`，看左上角和边框颜色：

```text
00 -> 蓝
01 -> 绿
10 -> 红
11 -> 白
```

如果标识颜色变化正常，说明 `mode_sw` 生效。若图像主体变化不明显，问题在图像处理效果或摄像头数据质量，不在拨码。

如果标识颜色不变：

```text
1. 确认烧录的是新的 vision_top.bit。
2. 确认拨的是 SW0/SW1。
3. 检查 constraints/ego1_template.xdc 中 mode_sw[0]=R1, mode_sw[1]=N4。
```

### 5.2 再判断 VGA 色彩

完整工程主体仍是灰度输出。如果画面主体偏黄，但左上角蓝/绿/红/白都正常，则 VGA 通道没有问题，偏黄更可能是手机拍摄白平衡或显示器色温。

如果蓝色标识也显示不出来或明显偏暗：

```text
检查 VGA 蓝色通道 vga_b[0..3]。
```

### 5.3 再判断摄像头数据质量

如果降速后仍然噪声很重，按优先级检查：

```text
1. 杜邦线是否过长，尤其 PCLK、D0-D7、GND。
2. 摄像头 GND 是否和 FPGA GND 可靠连接。
3. PCLK 是否接 J5-19/D15。
4. D0-D7 是否按信号名接，不是按物理顺序猜。
5. SIOD/SIOC 是否有上拉，camera_config_done 是否点亮。
6. OV7670 是否实际输出 RGB565，而不是 YUV。
7. RGB565 高低字节顺序是否需要交换。
```

## 6. 后续可选优化

如果本轮修改后仍然不清晰，下一步建议按顺序做：

```text
1. 做一个 OV7670 color bar 测试配置，判断数据线顺序和 RGB565 格式。
2. 增加 BYTE_SWAP 参数，分别测试 RGB565 高低字节顺序。
3. 降低 Sobel 阈值或提高阈值，找到适合现场光照的值。
4. 改用更短、更整齐的排线，并增加多根 GND 参考线。
5. 将 cam_siod 改为显式 IOBUF，并检查 SCCB ACK。
6. 用 Clocking Wizard/MMCM 生成规范的 VGA pixel clock 和 camera XCLK。
```

## 7. RGB565 与 YUV422 的选择

当前项目推荐使用：

```text
OV7670 输出 YUV422
FPGA 只取 Y 亮度字节
```

原因：

```text
1. 本项目最终显示的是灰度、平滑、Sobel 和素描，不需要真实彩色。
2. YUV422 的 Y 字节就是亮度，直接用于灰度处理，链路更短。
3. RGB565 需要正确的高低字节顺序和 RGB 位解释；一旦字节序或配置不一致，灰度会被错误计算。
4. 使用 Y 通道可以更快判断问题来自采样/布线，还是来自 RGB565 颜色格式解释。
```

当前代码配置：

```text
rtl/ov7670_config_rom.v:
  COM7 = 0x10，配置为 QVGA + YUV
  COM13 = 0x88，配合 TSLB 控制 YUV 字节顺序

rtl/vision_top.v:
  CAMERA_FORMAT = 1

rtl/ov7670_capture.v:
  FORMAT = 0: RGB565
  FORMAT = 1: YUV YUYV，只取 Y 字节
  FORMAT = 2: YUV UYVY，只取 Y 字节

constraints/ego1_template.xdc:
  SW2/SW3/SW4 调试输入已移除
```

当前工程已固定实测较优配置：

```text
YUV 取样相位 = 原 SW2=1
mode 01 = 3x3 锐化灰度
cam_xclk = 25 MHz
```

此前调试结论：

```text
1. SW2=1 时灰度图明显更清晰。
2. SW3 前后主体差异很小，不再保留为调试开关。
3. 25 MHz XCLK 不花屏，运动更平滑，优于 12.5 MHz。
```

## 8. 固定显示模式

完整工程当前 `mode_sw[1:0]`：

```text
00: 原始灰度，作为判断采集质量的基准
01: 3x3 锐化灰度
10: 连续 Sobel 强度图，黑底亮边
11: 平滑灰度 + 黑色边缘叠加
```

如果两种 YUV 格式都明显不对，再回退 RGB565：

```verilog
localparam CAMERA_FORMAT = 0;
```

并把 `rtl/ov7670_config_rom.v` 中 `COM7` 改回 RGB/QVGA 配置。

## 9. 分辨率上限

当前工程处理分辨率是：

```text
320 x 240
```

VGA 显示是：

```text
640 x 480
```

当前显示方式是把 320x240 放大到 640x480，因此会有可见的块状感。继续提高到真正 640x480 需要更大的帧缓存：

```text
640 * 480 * 8 bit = 2,457,600 bit
```

EGO1 Artix-7 片上 BRAM 不适合直接存一整帧 8-bit 640x480 图像。因此当前阶段更现实的优化方向是：

```text
1. 确认 YUV 相位正确。
2. 使用 25 MHz XCLK。
3. 改善布线和 PCLK 采样稳定性。
4. 调整 OV7670 曝光、增益、gamma 和 contrast 寄存器。
5. 调整 Sobel 低/高阈值。
6. 如需更高分辨率，需要降低像素位宽、使用外部存储，或改成流式显示结构。
```

当前 VGA 输出每个颜色通道只有 4 bit。工程已在 VGA 显示端加入 2x2 有序抖动：

```text
帧缓存仍保存 8-bit 灰度。
VGA 输出时不再直接丢弃低 4 bit，而是用相邻 2x2 显示像素表达低 4 bit 亮度。
这不会提高真实分辨率，但能减少 16 级灰度带来的色阶断层，让过渡更平滑。
```

## 10. 采样问题的硬件优先级

如果你判断主要是采样问题，优化优先级是：

```text
1. PCLK 接线最短，且必须是 J5-19/D15。
2. D0-D7 尽量等长、短线、不要松动。
3. 至少多接一根 GND，最好让 GND 靠近 PCLK 和数据线。
4. 不要让 XCLK/PCLK/D0-D7 与电源线长距离并行缠绕。
5. 当前 XCLK 固定 25 MHz；如果后续出现花屏，再回退测试 12.5 MHz。
6. 若有示波器，先看 PCLK 边沿是否干净，再看 D0-D7 是否在 PCLK 边沿附近抖动。
```
