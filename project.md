# FPGA Vision System Project Status

本文档是当前工程的快速交接文件。下次继续执行时，先读本文件，再读相关 `docs/*.md`。

## 1. 项目目标

课程项目目标：

```text
EGO1 FPGA + OV7670 摄像头 + VGA 显示器
实现实时图像采集、灰度处理、Sobel 边缘检测和素描风格显示
```

工具链：

```text
Vivado 2017.4
Verilog HDL
目标板卡: EGO1 V2.2
当前 FPGA part: xc7a35tcsg324-1
```

工程目录：

```text
G:\files\work\Grade_1_latter_class\Digital_system\FPGA_project\fpga_vision_system
```

当前新增功能开发分支：

```text
feature/restore-gray-rgb565-color
```

## 2. 主要文件

完整摄像头工程：

```text
rtl/vision_top.v
rtl/vision_rgb565_color_top.v
constraints/ego1_template.xdc
```

VGA-only 验证工程：

```text
rtl/vga_only_top.v
constraints/vga_only_ego1.xdc
```

关键文档：

```text
docs/vga_only_bringup.md
docs/pin_mapping_debug.md
docs/ov7670_j5_wiring.md
docs/image_quality_tuning.md
docs/hardware_bringup.md
docs/project_status_and_next_steps.md
```

## 3. 已完成事项

### 3.1 RTL 主体已完成

当前完整工程已经包含以下模块：

```text
rtl/vision_top.v              稳定 Y 通道灰度顶层集成
rtl/vision_rgb565_color_top.v RGB565 彩色实验顶层
rtl/ov7670_capture.v          OV7670 RGB565/YUV422 采集
rtl/ov7670_init.v             OV7670 SCCB 初始化控制
rtl/sccb_master.v             SCCB/I2C 写控制
rtl/ov7670_config_rom.v       OV7670 配置 ROM
rtl/rgb565_to_gray.v          RGB565 转灰度
rtl/image_window_3x3.v        3x3 滑动窗口
rtl/sobel_pipeline.v          Sobel 边缘检测
rtl/pixel_filter_pipeline.v   图像处理模式选择
rtl/frame_buffer_gray.v       灰度帧缓存
rtl/vga_timing.v              VGA 640x480 时序
rtl/reset_sync.v              复位同步
```

完整工程图像链路：

```text
OV7670 YUV422
-> ov7670_capture
-> direct Y luma / 3x3 window / Sobel
-> frame_buffer_gray
-> VGA 640x480 output
```

### 3.2 模块级仿真已通过

用户已在 Vivado 2017.4 中分别运行两个 testbench，结果通过：

```text
PASS: tb_ov7670_capture
PASS: tb_pixel_filter_pipeline, edge responses=8
```

含义：

```text
1. ov7670_capture 能把两个 8-bit 字节拼成 RGB565 像素。
2. pixel_valid、pixel_x、pixel_y 基本行为正确。
3. 图像处理链路能对人工黑白边缘产生 Sobel 响应。
```

限制：

```text
这只证明模块级行为仿真通过，不证明真实 OV7670 接线和摄像头输出已经正确。
```

### 3.3 VGA-only 实物验证已通过

已新增 VGA-only 顶层并实物验证成功：

```text
rtl/vga_only_top.v
constraints/vga_only_ego1.xdc
```

用户反馈 VGA 显示器已经能显示 4 种图案：

```text
00: 彩条
01: 灰度横向渐变
10: 黑白棋盘格
11: 边框 + 中心线
```

结论：

```text
EGO1 配置链路正常
100 MHz 时钟 P17 正常
复位 P15 正常
拨码开关 R1/N4 正常
板载 VGA RGB/HSYNC/VSYNC 引脚正常
VGA 640x480 时序正常
VGA 线和显示器正常
```

### 3.4 当前 Vivado 工程已建立多 run

在当前 `vivado_build/fpga_vision_system.xpr` 中已经建立以下 run：

```text
synth_vga_only   -> impl_vga_only
synth_vision_top -> impl_vision_top
```

其中：

```text
synth_vga_only:
  srcset      = sources_vga_only
  top         = vga_only_top
  constraints = constrs_vga_only
  xdc         = constraints/vga_only_ego1.xdc

synth_vision_top:
  srcset      = sources_1
  top         = vision_top
  constraints = constrs_vision
  xdc         = constraints/ego1_template.xdc
```

建立脚本：

```tcl
source vivado/add_vga_only_runs_to_current_project.tcl
```

注意：

```text
Vivado 2017.4 不支持对 run 使用 STEPS.SYNTH_DESIGN.ARGS.TOP。
本工程通过独立 source fileset 设置不同顶层。
```

### 3.5 J5 / OV7670 接线文档已完成

已新增：

```text
docs/ov7670_j5_wiring.md
docs/pin_mapping_debug.md
```

重要修正：

```text
cam_pclk 使用 FPGA 管脚 D15，对应 EGO1 J5-19。
不是 J5-20。
```

### 3.6 摄像头已有画面但质量待优化

用户在完整工程上已经看到摄像头画面轮廓，但画面存在：

```text
整体偏黄
噪声重
图像不清晰
mode_sw 四个模式差异不明显
```

已做第一轮 RTL 优化：

```text
1. 先将 cam_xclk 从 25 MHz 降到 12.5 MHz 以验证采样余量。
2. mode_sw 同步到 cam_pclk 和 pix_clk 两个时钟域。
3. VGA 左上角和边框新增模式颜色标识。
4. Sobel 阈值提高到 128。
5. mode 10/11 做了初版边缘/素描显示。
```

已做第二轮格式优化：

```text
1. OV7670 配置从 RGB565/QVGA 改为 YUV422/QVGA。
2. ov7670_capture 增加 FORMAT 参数：
   0 = RGB565
   1 = YUV YUYV，只取 Y 亮度
   2 = YUV UYVY，只取 Y 亮度
3. vision_top 当前 CAMERA_FORMAT = 1。
4. 实测 YUV 取样相位在原 SW2=1 时更清晰，现已写死为 `yuv_byte_order=1'b1`。
5. 实测 25 MHz XCLK 不花屏且拖动更平滑，现已写死 `cam_xclk=25 MHz`。
6. SW3/SW4 调试输入已从 `vision_top` 和完整工程 XDC 中移除。
7. SW2/M4 `style_page_sw` 在主 `vision_top` 中只保留端口兼容性，不再启用彩色页。
8. mode 01 在原功能页默认使用 3x3 锐化灰度图，不再需要 SW3 控制。
9. VGA 输出端新增 2x2 有序抖动，把帧缓存 8-bit 灰度的低 4 bit 转换为空间亮度，减少 4-bit VGA 灰阶断层。
10. 新增 `vision_rgb565_color_top` 独立彩色实验顶层，使用 RGB565 摄像头配置和 9-bit RGB333 彩色帧缓存。
11. Sobel/漫画显示已优化：
   mode 10 = 白底黑线草图，强边缘为黑线，弱边缘为浅灰线。
   mode 11 = 五级灰度漫画化 + 黑色轮廓线，用少量灰阶色块模拟漫画/素描效果。
```

相关说明：

```text
docs/image_quality_tuning.md
```

## 4. 当前必须遵守的硬件事实

EGO1 J5 是 2x18 双排针，共 36 针。

编号方式：

```text
顶部
左列: 36  右列: 35
左列: 34  右列: 33
左列: 32  右列: 31
...
左列:  2  右列:  1
底部
```

按用户照片方向：

```text
VGA 接口在上
拨码开关在下
J5 在左侧竖放
```

大概率是：

```text
靠板子外侧列: 偶数列 36,34,32,...,2
靠板子内侧列: 奇数列 35,33,31,...,1
```

但接摄像头前必须用万用表确认：

```text
J5-35/J5-36 = 3.3 V
J5-33/J5-34 = GND
```

OV7670 模块是 2x9，共 18 针。不能整体插到 J5 上，必须用杜邦线按信号逐根连接。

## 5. 当前 OV7670 接线目标

按信号名连接，不能按物理排数猜。

| OV7670 信号 | EGO1 J5 | FPGA 管脚 |
|---|---:|---|
| `VCC` / `3V3` | `J5-35` 或 `J5-36` | 3.3 V |
| `GND` | `J5-33` 或 `J5-34` | GND |
| `PWDN` | `J5-1` | `B16` |
| `VSYNC` | `J5-2` | `B17` |
| `HREF` | `J5-3` | `A15` |
| `D0` | `J5-4` | `A16` |
| `D1` | `J5-5` | `A13` |
| `D2` | `J5-6` | `A14` |
| `D3` | `J5-7` | `B18` |
| `D4` | `J5-8` | `A18` |
| `D5` | `J5-9` | `F13` |
| `D6` | `J5-10` | `F14` |
| `D7` | `J5-11` | `B13` |
| `XCLK` / `MCLK` | `J5-12` | `B14` |
| `SIOC` / `SCL` | `J5-13` | `D14` |
| `SIOD` / `SDA` | `J5-14` | `C14` |
| `RESET` / `RST` | `J5-15` | `B11` |
| `PCLK` | `J5-19` | `D15` |

未使用：

```text
J5-16, J5-17, J5-18, J5-20 到 J5-32
```

安全要求：

```text
1. 未确认 OV7670 模块 VCC/GND 前，不允许上电。
2. OV7670 VCC 只接 3.3 V，不接 5 V。
3. PCLK 必须接 J5-19/D15。
4. 不允许把 OV7670 2x9 整体直接插到 J5。
```

## 6. 待完成目标

### 6.1 生成完整工程 bitstream

在 Vivado Tcl Console 中运行：

```tcl
reset_run synth_vision_top
reset_run impl_vision_top
launch_runs synth_vision_top -jobs 4
wait_on_run synth_vision_top
launch_runs impl_vision_top -to_step write_bitstream -jobs 4
wait_on_run impl_vision_top
```

bitstream 位置通常是：

```text
vivado_build/fpga_vision_system.runs/impl_vision_top/vision_top.bit
```

烧录前检查：

```tcl
open_run impl_vision_top
report_timing_summary
report_drc
```

### 6.2 安全连接 OV7670

推荐分阶段连接：

```text
1. 只接 VCC/GND，确认模块不发热。
2. 断电。
3. 接 XCLK、RESET、PWDN。
4. 上电测 XCLK：约 25 MHz。
5. 断电。
6. 接 SIOC、SIOD。
7. 上电观察 camera_config_done LED。
8. 断电。
9. 接 PCLK、VSYNC、HREF、D0-D7。
10. 上电后 mode_sw=00 看灰度图。
```

### 6.3 逐级测量摄像头信号

建议用示波器或逻辑分析仪按顺序测：

| 顺序 | 信号 | 期望现象 |
|---:|---|---|
| 1 | `XCLK` | 约 25 MHz 连续时钟 |
| 2 | `RESET` | 释放后为高 |
| 3 | `PWDN` | 工作时为低 |
| 4 | `SIOC` | 初始化阶段有脉冲 |
| 5 | `SIOD` | 初始化阶段有数据变化 |
| 6 | `camera_config_done` | LED 点亮 |
| 7 | `PCLK` | 摄像头输出像素时钟 |
| 8 | `VSYNC` | 周期性帧同步 |
| 9 | `HREF` | 行有效脉冲 |
| 10 | `D0-D7` | 随 PCLK 变化 |

### 6.4 图像显示验证

主顶层 `vision_top` 的 `mode_sw[1:0]`：

```text
00: 灰度图
01: 锐化灰度图
10: 白底黑线草图
11: 五级灰度漫画化 + 黑色轮廓线
```

`SW2/M4 style_page_sw` 在主顶层中不再切换彩色页。彩色实验需要把 Vivado top 改为 `vision_rgb565_color_top`：

```text
SW2 = 0: RGB565 摄像头下的灰度处理页
00: RGB565 转灰度
01: 锐化灰度图
10: 白底黑线草图
11: 五级灰度漫画化 + 黑色轮廓线

SW2 = 1: 彩色扩展页
00: 彩色原图
01: 彩色像素漫画风
10: 白底黑线草图
11: 五级灰度漫画化 + 黑色轮廓线
```

要求：

```text
先用 00 灰度图验证摄像头采集链路。
灰度图稳定后，再测试 10 Sobel 和 11 素描。
```

## 7. 当前风险和技术债

当前仍未完成实物验证：

```text
OV7670 模块针脚丝印和实际排针顺序
OV7670 到 J5 的杜邦线连接
SCCB 初始化是否被摄像头 ACK
cam_pclk / href / vsync / data 是否正常输出
YUV 字节顺序已写死为原 SW2=1 的相位；若后续异常先测 FORMAT=2，再切换 vision_rgb565_color_top 测 RGB565
HREF/VSYNC 极性是否和实际模块一致
Sobel 阈值是否适合实际光照
```

代码层技术债：

```text
1. cam_siod 当前使用 Verilog 三态推断，后续可改为显式 IOBUF。
2. SCCB master 当前不采样 ACK，camera_config_done 只代表写流程结束。
3. 25 MHz VGA 像素时钟和 25 MHz 摄像头 XCLK 当前由 fabric 分频产生，最终可改 Clocking Wizard/MMCM。
4. XDC 目前没有完整板级 input/output delay。
5. Sobel 低阈值/高阈值后续需要按实物光照调整。
```

## 8. 下次继续时的优先顺序

若用户要继续硬件验证，按顺序执行：

```text
1. 读 docs/ov7670_j5_wiring.md。
2. 确认 OV7670 模块 18 个针脚的丝印或卖家 pinout。
3. 用万用表确认 J5-35/36 是 3.3 V，J5-33/34 是 GND。
4. 生成完整工程 vision_top.bit。
5. 分阶段接 OV7670。
6. 先测 XCLK。
7. 再测 SCCB。
8. 再测 PCLK/HREF/VSYNC/DATA。
9. mode_sw=00 看灰度图。
10. 最后测试 Sobel/素描。
```

若用户要继续文档/报告，重点记录：

```text
VGA-only 已实物验证成功
当前 OV7670 接线仍是最大风险
PCLK 修正为 J5-19/D15
完整摄像头链路已经有画面，但图像质量和模式效果仍需调试
```
