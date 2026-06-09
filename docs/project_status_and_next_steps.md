# FPGA视觉处理项目现状与后续步骤

日期：2026-05-19

本文档说明当前工程完成度、工程疏漏、Vivado 2017.4 创建/打开、仿真、综合实现、上板验证流程，以及验证完成后的下一步方向。

## 1. 当前工程状态

工程主体目录：

```text
fpga_vision_system/
```

当前工程已经具备一个可综合、可离线仿真的 FPGA 实时视觉处理原型。

- 开发板：EGO1，当前 Vivado part 按 `xc7a35tcsg324-1` 处理。
- 摄像头：OV7670。
- 显示：VGA 640x480。
- 内部处理分辨率：320x240，再以 2 倍最近邻方式输出到 VGA。
- 功能链路：主顶层使用 OV7670 YUV422 采集并直接取 Y 亮度 -> 3x3窗口 -> 锐化/Sobel/漫画化 -> 帧缓存 -> VGA显示。
- 模式选择：`mode_sw[1:0]`
  - `00`：直接 Y 通道灰度图。
  - `01`：锐化灰度图。
  - `10`：白底黑线草图。
  - `11`：五级灰度漫画化 + 黑色轮廓线。
- `style_page_sw` 仅保留端口兼容性，不启用第二显示页。

当前主要 RTL：

```text
rtl/vision_top.v              稳定 Y 通道灰度顶层集成
rtl/ov7670_capture.v          OV7670 RGB565/YUV422 字节采集
rtl/ov7670_init.v             OV7670 初始化控制
rtl/sccb_master.v             SCCB/I2C写控制
rtl/ov7670_config_rom.v       OV7670寄存器配置表
rtl/rgb565_to_gray.v          RGB565转灰度
rtl/image_window_3x3.v        3x3滑动窗口
rtl/sobel_pipeline.v          Sobel边缘检测
rtl/pixel_filter_pipeline.v   图像处理模式选择
rtl/frame_buffer_gray.v       灰度帧缓存
rtl/vga_timing.v              VGA时序
rtl/reset_sync.v              复位同步
```

当前辅助文件：

```text
tb/tb_ov7670_capture.v
tb/tb_pixel_filter_pipeline.v
scripts/run_iverilog.ps1
scripts/run_vivado_impl.ps1
vivado/create_project.tcl
vivado/run_synth_impl.tcl
constraints/ego1_template.xdc
docs/hardware_bringup.md
```

本次复核结果：

- Icarus Verilog 离线仿真通过。
- Vivado 2017.4 综合通过。
- Vivado 2017.4 实现通过到 `route_design`。
- Post-route timing 已满足约束：WNS 约 5.224 ns，TNS 0.000 ns。
- 资源占用较低：Slice LUTs 495，Slice Registers 298，Block RAM Tile 17.5，DSP 0，Bonded IOB 35。
- 仍有硬件相关 DRC warning，例如 `cam_siod` I/O buffer、BRAM 异步控制、配置电压属性等；这些不阻止当前 route_design，但上板前应逐项确认。

已清理掉的生成产物：

```text
.Xil/
sim_build/
vivado_build/
vivado_reports/
vivado.jou
vivado.log
vivado_*.backup.jou
vivado_*.backup.log
```

这些都是仿真、综合、实现或 Vivado 运行日志产物，可由脚本重新生成，不应作为最终工程源码提交或打包。

## 2. 工程是否还有疏漏

结论：当前工程作为“离线可综合的 FPGA 视觉处理原型”基本完整；但还不是已经完成硬件验证的最终作品。主要风险集中在真实板卡和摄像头阶段。

必须补做或确认：

1. 确认 EGO1 实际 FPGA 型号是否为 `xc7a35tcsg324-1`。如果不同，修改 `vivado/create_project.tcl`。
2. 确认 `constraints/ego1_template.xdc` 中 J5 扩展口与 OV7670 模块排线完全一致。
3. 当前批处理脚本故意不生成 bitstream，因为摄像头排线尚未确认。确认接线后再生成 bitstream。
4. 当前 `cam_siod` 使用 Verilog 三态推断。若 Vivado 或硬件表现异常，可改成显式 `IOBUF`。
5. `sccb_master.v` 当前只发写序列，不采样 ACK；`camera_config_done` 代表写流程完成，不代表摄像头一定 ACK 成功。
6. 当前 VGA 像素时钟约 25 MHz，摄像头 XCLK 固定约 25 MHz，均由 100 MHz 简单分频得到。课程验收可先用；若要求规范，后期改用 Clocking Wizard/MMCM。
7. XDC 目前有基础时钟约束，但没有摄像头输入延迟、VGA输出延迟等板级 I/O 时序约束。课程项目通常可以先完成现象验证，再在报告中说明。
8. Vivado DRC 提示缺少 `CFGBVS` 和 `CONFIG_VOLTAGE` 配置属性。生成最终 bitstream 前应按 EGO1 板卡配置电压补到 XDC。
9. 图像滤波模式的边界像素不会完整产生 3x3窗口，这是正常现象。
10. 目前有 OV7670采集和图像处理 testbench，但没有完整“摄像头输入到 VGA输出”的系统级视频仿真。硬件前建议先做 VGA-only 测试图案。

## 3. Vivado 2017.4 创建和打开工程

先进入工程目录：

```powershell
cd G:\files\work\Grade_1_latter_class\Digital_system\FPGA_project\fpga_vision_system
```

在 Vivado GUI 中创建工程：

1. 打开 Vivado 2017.4。
2. 在 Tcl Console 中执行：

```tcl
cd G:/files/work/Grade_1_latter_class/Digital_system/FPGA_project/fpga_vision_system
source vivado/create_project.tcl
```

3. 脚本会生成：

```text
vivado_build/fpga_vision_system.xpr
```

4. 以后可以直接在 Vivado 中打开这个 `.xpr` 文件。

PowerShell 批处理方式：

```powershell
.\scripts\run_vivado_impl.ps1
```

该脚本会调用 Vivado 2017.4，重新创建工程，运行 `synth_1` 和 `impl_1` 到 `route_design`，并输出报告到：

```text
vivado_reports/
```

注意：当前脚本不会生成 `.bit`，这是为了避免接线未确认时误上板。

## 4. 离线仿真方法

如果本机已安装 Icarus Verilog，运行：

```powershell
cd G:\files\work\Grade_1_latter_class\Digital_system\FPGA_project\fpga_vision_system
.\scripts\run_iverilog.ps1
```

该脚本会检查：

- OV7670 RGB565 双字节拼接、YUV 直接取 Y 和坐标计数。
- 灰度/窗口/Sobel处理链路是否能对人工边缘产生响应。
- 全部 RTL 文件是否能以 `vision_top` 为顶层完成编译检查。

期望结果：

```text
PASS: tb_ov7670_capture
PASS: tb_pixel_filter_pipeline, edge responses=...
All offline simulations passed.
```

如果使用 Vivado Simulator：

1. 打开 `vivado_build/fpga_vision_system.xpr`。
2. 在 Flow Navigator 中选择 Simulation。
3. 先运行 `tb_ov7670_capture`。
4. 再运行 `tb_pixel_filter_pipeline`。
5. 看 Console 是否出现 PASS 信息。

## 5. 综合、实现和报告查看

批处理方式：

```powershell
.\scripts\run_vivado_impl.ps1
```

GUI方式：

1. 打开或创建 Vivado 工程。
2. 确认顶层为 `vision_top`。
3. 点击 Run Synthesis。
4. 综合完成后点击 Run Implementation。
5. 查看 Timing Summary、Utilization、DRC。

重点检查：

- Timing Summary 中 WNS 是否大于 0。
- Utilization 中 BRAM 使用是否合理。
- DRC 中是否有阻止 bitstream 的错误。
- XDC 引脚是否全部约束，无未约束顶层端口。

已有离线实现结果曾经通过 `route_design`，但生成产物已经清理。需要时重新跑脚本即可。

## 6. 上板验证步骤

不要直接烧录完整摄像头工程，建议逐步验证。

### 6.1 检查硬件

1. 确认 EGO1 板卡型号和 FPGA part。
2. 查板卡原理图/手册，确认 100 MHz 时钟、复位、VGA、拨码开关、LED 引脚。
3. 对照 `constraints/ego1_template.xdc` 检查 OV7670 到 J5 的每一根线。
4. 确认摄像头供电电压、GND、SIOC/SIOD 上拉是否正确。
5. 确认 `cam_pclk` 接到 XDC 中标注的 J5-19/MRCC 引脚。

### 6.2 先验证 VGA

建议先临时做一个 VGA 彩条或灰阶测试顶层，只验证：

- 25 MHz 左右像素时钟是否可用。
- 显示器是否能锁定 640x480。
- HSYNC/VSYNC 极性和 RGB 引脚是否正确。

VGA 单独验证通过后，再接摄像头链路。

### 6.3 验证摄像头时钟和初始化

1. 下载工程前确认 XDC 接线无误。
2. 用示波器/逻辑分析仪检查 `cam_xclk` 是否约 25 MHz。
3. 检查 `cam_sioc` 和 `cam_siod` 是否有 SCCB 配置波形。
4. 观察 `camera_config_done` LED 是否最终点亮。
5. 检查 OV7670 是否输出 `cam_pclk`、`cam_href`、`cam_vsync`。

### 6.4 验证图像

1. 先把 `mode_sw` 设为 `00`，只看灰度图。
2. 如果无图像，优先检查：
   - 摄像头供电和 GND。
   - `cam_xclk` 是否存在。
   - `cam_pclk` 是否存在。
   - `HREF/VSYNC` 极性是否与 RTL 假设一致。
   - RGB565 字节顺序是否反了。
   - OV7670 是否实际输出 RGB565，而不是 YUV。
3. 灰度图稳定后再切到 `10` 看 Sobel。
4. 如果 Sobel 太黑或太白，调整 `rtl/pixel_filter_pipeline.v` 中的 `SOBEL_LOW_THRESHOLD` 和 `SOBEL_THRESHOLD`。
5. 最后测试 `11` 边缘叠加模式。

### 6.5 生成 bitstream 和烧录

接线确认后，在 Vivado GUI 中：

1. Run Synthesis。
2. Run Implementation。
3. Generate Bitstream。
4. Open Hardware Manager。
5. Open Target -> Auto Connect。
6. Program Device。
7. 选择生成的 bitstream，通常在：

```text
vivado_build/fpga_vision_system.runs/impl_1/vision_top.bit
```

也可以在硬件确认后把 `vivado/run_synth_impl.tcl` 的 implementation 步骤扩展到 `write_bitstream`，或在 Vivado Tcl Console 手动执行：

```tcl
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
```

## 7. 验证完成后的下一步

当灰度、Sobel、素描模式都能在 VGA 上稳定显示后，项目进入“完善和收尾”阶段。

优先级最高的收尾工作：

1. 固化最终 XDC：把实际使用的 OV7670 接线、拨码开关、LED、VGA 引脚全部确认并保留。
2. 固化最终 OV7670 寄存器配置：记录摄像头输出格式、分辨率、PCLK、HREF/VSYNC 极性。
3. 固化最终演示模式：至少保证灰度、白底黑线草图和漫画化模式稳定。
4. 调整 Sobel 低/高阈值：根据实际光照选择适合演示的 `SOBEL_LOW_THRESHOLD` 和 `SOBEL_THRESHOLD`。
5. 补一个 VGA-only 测试或保留调试说明，便于答辩时解释排错流程。
6. 用 Clocking Wizard/MMCM 替换简单分频，如果老师对时钟规范性要求较高。
7. 拍摄或录制演示材料：原始场景、灰度输出、边缘输出、模式切换。
8. 整理最终报告：说明系统结构、模块划分、关键 Verilog、仿真结果、综合资源、上板现象、问题和改进。
9. 打包工程时只保留源码、约束、脚本、文档，不保留 `.Xil`、`sim_build`、`vivado_build`、`vivado_reports`、`.jou`、`.log`。

可选提升方向：

- 增加按键或拨码控制 Sobel 阈值。
- 增加 VGA 彩色叠加：原图灰度 + 边缘高亮。
- 增加简单形态学处理，让边缘更连续。
- 做简单目标轮廓框或连通域统计，作为课程项目加分项。
- 把 SCCB ACK 检测补完整，提高摄像头初始化可靠性。

## 8. 推荐完成路线

建议按这个顺序完成：

```text
1. 离线仿真通过
2. Vivado综合/实现通过
3. 确认EGO1型号和XDC
4. VGA-only测试图案上板通过
5. 摄像头XCLK/SCCB/PCLK/HREF/VSYNC验证
6. 灰度图稳定显示
7. Sobel和素描模式稳定显示
8. 生成最终bitstream
9. 拍摄演示视频和图片
10. 写最终报告并清理工程目录
```

当前项目已经完成第 1、2 步的离线工程基础；第 3 步开始需要结合真实板卡和摄像头确认。
