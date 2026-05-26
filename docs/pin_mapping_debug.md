# 引脚映射与调试对照表

本文档汇总当前工程使用的 EGO1 V2.2 / Artix-7 引脚映射，便于 VGA-only 验证、OV7670 接线检查和实物调试。

当前工程默认 FPGA part：

```text
xc7a35tcsg324-1
```

完整工程顶层：

```text
rtl/vision_top.v
constraints/ego1_template.xdc
```

VGA-only 验证顶层：

```text
rtl/vga_only_top.v
constraints/vga_only_ego1.xdc
```

## 1. 系统时钟、复位、拨码、LED

| 顶层信号 | 方向 | FPGA 管脚 | I/O 标准 | 板级功能 | 说明 |
|---|---:|---|---|---|---|
| `clk_100m` | 输入 | `P17` | `LVCMOS33` | EGO1 100 MHz 系统时钟 | VGA 像素时钟和摄像头 XCLK 均由该时钟分频得到 |
| `reset_n` | 输入 | `P15` | `LVCMOS33` | 复位按键/复位信号 | 低有效 |
| `mode_sw[0]` | 输入 | `R1` | `LVCMOS33` | 拨码开关 bit0 | VGA-only 中选择图案；完整工程中选择图像模式 |
| `mode_sw[1]` | 输入 | `N4` | `LVCMOS33` | 拨码开关 bit1 | VGA-only 中选择图案；完整工程中选择图像模式 |
| `camera_config_done` | 输出 | `K3` | `LVCMOS33` | 状态 LED | 完整工程中表示 SCCB 配置流程已发送完成 |
| `test_led` | 输出 | `K3` | `LVCMOS33` | 状态 LED | VGA-only 中慢速闪烁，确认 FPGA 逻辑运行 |

注意：`camera_config_done` 和 `test_led` 都映射到 `K3`，但它们属于不同顶层，不会在同一个 bitstream 中同时存在。

## 2. VGA 映射

VGA 使用 EGO1 板载 VGA 接口，不需要外接到 J5。使用标准 VGA 线连接板载 15 针 VGA 接口到显示器。

| 顶层信号 | 方向 | FPGA 管脚 | I/O 标准 | 板级功能 | 调试说明 |
|---|---:|---|---|---|---|
| `vga_r[0]` | 输出 | `F5` | `LVCMOS33` | VGA 红色 bit0 | 红色最低位 |
| `vga_r[1]` | 输出 | `C6` | `LVCMOS33` | VGA 红色 bit1 |  |
| `vga_r[2]` | 输出 | `C5` | `LVCMOS33` | VGA 红色 bit2 |  |
| `vga_r[3]` | 输出 | `B7` | `LVCMOS33` | VGA 红色 bit3 | 红色最高位 |
| `vga_g[0]` | 输出 | `B6` | `LVCMOS33` | VGA 绿色 bit0 | 绿色最低位 |
| `vga_g[1]` | 输出 | `A6` | `LVCMOS33` | VGA 绿色 bit1 |  |
| `vga_g[2]` | 输出 | `A5` | `LVCMOS33` | VGA 绿色 bit2 |  |
| `vga_g[3]` | 输出 | `D8` | `LVCMOS33` | VGA 绿色 bit3 | 绿色最高位 |
| `vga_b[0]` | 输出 | `C7` | `LVCMOS33` | VGA 蓝色 bit0 | 蓝色最低位 |
| `vga_b[1]` | 输出 | `E6` | `LVCMOS33` | VGA 蓝色 bit1 |  |
| `vga_b[2]` | 输出 | `E5` | `LVCMOS33` | VGA 蓝色 bit2 |  |
| `vga_b[3]` | 输出 | `E7` | `LVCMOS33` | VGA 蓝色 bit3 | 蓝色最高位 |
| `vga_hsync` | 输出 | `D7` | `LVCMOS33` | VGA 行同步 | 640x480 模式下应有约 31.5 kHz 周期波形 |
| `vga_vsync` | 输出 | `C4` | `LVCMOS33` | VGA 场同步 | 640x480 模式下应有约 60 Hz 周期波形 |

VGA-only 已验证通过后，可认为以下内容基本正确：

```text
P17 系统时钟
P15 复位
R1/N4 拨码输入
K3 LED 输出
VGA RGB 管脚
VGA HSYNC/VSYNC 管脚
640x480 VGA 时序
```

## 3. OV7670 到 J5 扩展口映射

OV7670 当前假设接在 EGO1 的 J5 扩展口。接线前必须确认摄像头模块排针顺序和 J5 编号方向，不能只按排线颜色猜。

| 顶层信号 | 方向 | FPGA 管脚 | J5 位置 | I/O 标准 | OV7670 信号 | 调试说明 |
|---|---:|---|---|---|---|---|
| `cam_pwdn` | 输出 | `B16` | `J5-1` | `LVCMOS33` | `PWDN` | 当前工程输出 0，使摄像头不掉电 |
| `cam_vsync` | 输入 | `B17` | `J5-2` | `LVCMOS33` | `VSYNC` | 帧同步；应周期性跳变 |
| `cam_href` | 输入 | `A15` | `J5-3` | `LVCMOS33` | `HREF` | 行有效；有图像输出时应成组跳变 |
| `cam_data[0]` | 输入 | `A16` | `J5-4` | `LVCMOS33` | `D0` | 摄像头数据 bit0 |
| `cam_data[1]` | 输入 | `A13` | `J5-5` | `LVCMOS33` | `D1` | 摄像头数据 bit1 |
| `cam_data[2]` | 输入 | `A14` | `J5-6` | `LVCMOS33` | `D2` | 摄像头数据 bit2 |
| `cam_data[3]` | 输入 | `B18` | `J5-7` | `LVCMOS33` | `D3` | 摄像头数据 bit3 |
| `cam_data[4]` | 输入 | `A18` | `J5-8` | `LVCMOS33` | `D4` | 摄像头数据 bit4 |
| `cam_data[5]` | 输入 | `F13` | `J5-9` | `LVCMOS33` | `D5` | 摄像头数据 bit5 |
| `cam_data[6]` | 输入 | `F14` | `J5-10` | `LVCMOS33` | `D6` | 摄像头数据 bit6 |
| `cam_data[7]` | 输入 | `B13` | `J5-11` | `LVCMOS33` | `D7` | 摄像头数据 bit7 |
| `cam_xclk` | 输出 | `B14` | `J5-12` | `LVCMOS33` | `XCLK` | 当前约 25 MHz；先测这个信号 |
| `cam_sioc` | 输出 | `D14` | `J5-13` | `LVCMOS33` | `SIOC` | SCCB/I2C 时钟 |
| `cam_siod` | 双向 | `C14` | `J5-14` | `LVCMOS33` | `SIOD` | SCCB/I2C 数据；通常需要上拉 |
| `cam_reset_n` | 输出 | `B11` | `J5-15` | `LVCMOS33` | `RESET` | 高有效释放摄像头复位 |
| `cam_pclk` | 输入 | `D15` | `J5-19` | `LVCMOS33` | `PCLK` | 摄像头像素时钟；必须接到当前指定的 J5-19/MRCC |

重点风险：

```text
1. J5 编号方向看反会导致整排信号错接。
2. 摄像头模块 D0-D7 顺序可能和排针物理顺序不同。
3. cam_pclk 当前必须接 J5-19/D15。
4. SIOD/SIOC 如果没有合适上拉，SCCB 初始化可能失败。
5. 摄像头供电电压和 GND 必须先确认，避免损坏模块。
```

## 4. 完整工程模式选择

完整工程 `vision_top` 中，`mode_sw[1:0]` 含义为：

| `mode_sw[1:0]` | 模式 | 说明 |
|---|---|---|
| `00` | 灰度图 | 首次摄像头调试优先使用此模式 |
| `01` | 平滑灰度图 | 经过简单平滑处理 |
| `10` | Sobel 边缘 | 输出梯度幅值 |
| `11` | 素描风格 | 白底黑边效果 |

摄像头首次上板时，不建议先看 Sobel。先用 `00` 灰度图确认采集链路，再切换其它模式。

## 5. 摄像头实物调试顺序

VGA-only 已经通过后，下一步按以下顺序推进。

### 5.1 生成完整工程 bitstream

在当前 Vivado 工程中使用前面建立的完整工程 run：

```tcl
reset_run synth_vision_top
reset_run impl_vision_top
launch_runs synth_vision_top -jobs 4
wait_on_run synth_vision_top
launch_runs impl_vision_top -to_step write_bitstream -jobs 4
wait_on_run impl_vision_top
```

bitstream 通常位于：

```text
vivado_build/fpga_vision_system.runs/impl_vision_top/vision_top.bit
```

烧录前检查：

```tcl
open_run impl_vision_top
report_timing_summary
report_drc
```

### 5.2 断电接 OV7670

断电后连接 OV7670。先确认：

```text
VCC
GND
XCLK
PCLK
VSYNC
HREF
D0-D7
SIOC
SIOD
RESET
PWDN
```

不要在不确认电源和 GND 的情况下上电。

### 5.3 上电后先测基础信号

建议用示波器或逻辑分析仪按顺序测：

| 顺序 | 信号 | 期望现象 | 如果异常，优先检查 |
|---:|---|---|---|
| 1 | `cam_xclk` | 约 25 MHz 连续时钟 | `clk_100m`、`reset_n`、`B14/J5-12` 接线 |
| 2 | `cam_reset_n` | 复位释放后为高 | 复位键、`B11/J5-15` |
| 3 | `cam_pwdn` | 应为低 | `B16/J5-1` |
| 4 | `cam_sioc` | 初始化阶段有时钟脉冲 | SCCB 控制、`D14/J5-13` |
| 5 | `cam_siod` | 初始化阶段有数据变化 | 上拉、电平、`C14/J5-14` |
| 6 | `camera_config_done` | 初始化结束后 LED 点亮 | SCCB 流程是否完成 |
| 7 | `cam_pclk` | 摄像头输出像素时钟 | 摄像头供电、XCLK、RESET/PWDN、`D15/J5-19` |
| 8 | `cam_vsync` | 周期性帧同步 | 摄像头是否开始输出帧 |
| 9 | `cam_href` | 行有效脉冲 | 摄像头输出格式/时序 |
| 10 | `cam_data[7:0]` | 随 PCLK 变化 | 数据线顺序、摄像头输出格式 |

### 5.4 看图像

验证显示时按顺序：

```text
1. mode_sw = 00，看灰度图
2. 如果有灰度图但颜色/亮度异常，检查 RGB565 字节顺序和 D0-D7 顺序
3. 灰度图稳定后，切 mode_sw = 10 看 Sobel
4. Sobel 过黑或过白，再调整 Sobel 阈值
5. 最后测试 mode_sw = 11 素描模式
```

## 6. 约束文件来源

当前映射来自：

```text
constraints/ego1_template.xdc
constraints/vga_only_ego1.xdc
```

调试时以 XDC 和本表为准；如果你实测发现板卡版本或摄像头转接板不同，应先修改 XDC，再重新综合实现并生成 bitstream。
