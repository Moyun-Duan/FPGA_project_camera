# VGA-only 实物验证说明

本文档用于先验证 EGO1 FPGA 到 VGA 显示器的链路。该验证不使用 OV7670，也不使用帧缓存、图像处理、SCCB 初始化模块。

## 1. 本次新增文件

```text
rtl/vga_only_top.v
constraints/vga_only_ego1.xdc
vivado/create_vga_only_project.tcl
vivado/run_vga_only_bitstream.tcl
scripts/run_vivado_vga_only.ps1
docs/vga_only_bringup.md
```

`vga_only_top` 使用 100 MHz 系统时钟四分频得到约 25 MHz 像素时钟，输出 640x480 VGA 测试图案。`mode_sw[1:0]` 用于选择图案：

```text
00: 彩条
01: 灰度横向渐变
10: 黑白棋盘格
11: 边框 + 中心线
```

`test_led` 会慢速闪烁，用于确认 FPGA 时钟和配置后的逻辑正在运行。

## 2. 约束检查

VGA-only 工程只启用：

```text
constraints/vga_only_ego1.xdc
```

不要同时启用完整摄像头工程的：

```text
constraints/ego1_template.xdc
```

关键管脚如下：

```text
clk_100m   -> P17
reset_n    -> P15
mode_sw[0] -> R1
mode_sw[1] -> N4
test_led   -> K3

vga_r[0]   -> F5
vga_r[1]   -> C6
vga_r[2]   -> C5
vga_r[3]   -> B7
vga_g[0]   -> B6
vga_g[1]   -> A6
vga_g[2]   -> A5
vga_g[3]   -> D8
vga_b[0]   -> C7
vga_b[1]   -> E6
vga_b[2]   -> E5
vga_b[3]   -> E7
vga_hsync  -> D7
vga_vsync  -> C4
```

实物验证前，对照 EGO1 V2.2 原理图确认这些管脚和板载 VGA 接口一致。

## 3. 推荐执行方式：批处理生成 bitstream

在 PowerShell 中执行：

```powershell
cd G:\files\work\Grade_1_latter_class\Digital_system\FPGA_project\fpga_vision_system
.\scripts\run_vivado_vga_only.ps1
```

脚本会创建独立工程：

```text
vivado_vga_only_build/fpga_vga_only.xpr
```

并生成 bitstream：

```text
vivado_vga_only_build/fpga_vga_only.runs/impl_1/vga_only_top.bit
```

报告输出到：

```text
vivado_vga_only_reports/
```

重点查看：

```text
vivado_vga_only_reports/post_impl_timing_summary.txt
vivado_vga_only_reports/post_impl_drc.txt
```

要求：

```text
Timing Summary: WNS >= 0
DRC: 没有阻止 bitstream 的 Error
```

## 4. GUI 执行方式

打开 Vivado 2017.4，在 Tcl Console 执行：

```tcl
cd G:/files/work/Grade_1_latter_class/Digital_system/FPGA_project/fpga_vision_system
source vivado/create_vga_only_project.tcl
```

然后在 GUI 中：

```text
1. 确认顶层模块是 vga_only_top
2. 确认约束文件只有 constraints/vga_only_ego1.xdc
3. Run Synthesis
4. Run Implementation
5. Generate Bitstream
6. Open Hardware Manager
7. Open Target -> Auto Connect
8. Program Device
9. 选择 vga_only_top.bit
```

bitstream 路径通常为：

```text
vivado_vga_only_build/fpga_vga_only.runs/impl_1/vga_only_top.bit
```

## 5. 在当前 Vivado 工程中建立不同 Synth/Impl Runs

如果你希望在当前已经打开的 `fpga_vision_system.xpr` 里同时保留完整工程和 VGA-only 验证工程，不要反复手动切换同一个 `synth_1/impl_1`。推荐建立两套独立 run，并让它们绑定不同的 source fileset 和 constraints fileset：

```text
synth_vga_only   -> impl_vga_only
synth_vision_top -> impl_vision_top
```

其中：

```text
synth_vga_only:
  顶层模块: vga_only_top
  源码集合: sources_vga_only
  约束集合: constrs_vga_only
  约束文件: constraints/vga_only_ego1.xdc

synth_vision_top:
  顶层模块: vision_top
  源码集合: sources_1
  约束集合: constrs_vision
  约束文件: constraints/ego1_template.xdc
```

### 5.1 Tcl 自动建立方式

先打开当前 Vivado 工程：

```text
vivado_build/fpga_vision_system.xpr
```

然后在 Tcl Console 执行：

```tcl
cd G:/files/work/Grade_1_latter_class/Digital_system/FPGA_project/fpga_vision_system
source vivado/add_vga_only_runs_to_current_project.tcl
```

脚本会在当前工程中添加：

```text
sources_vga_only
constraints/vga_only_ego1.xdc
rtl/vga_only_top.v
constrs_vga_only
constrs_vision
synth_vga_only
impl_vga_only
synth_vision_top
impl_vision_top
```

Vivado 2017.4 中不要使用下面这种方式设置 synthesis run 顶层：

```tcl
set_property STEPS.SYNTH_DESIGN.ARGS.TOP vga_only_top [get_runs synth_vga_only]
```

该属性在 Vivado 2017.4 project run 对象上不存在。正确做法是让 `synth_vga_only` 绑定 `sources_vga_only`，并设置：

```tcl
set_property top vga_only_top [get_filesets sources_vga_only]
```

运行 VGA-only 验证：

```tcl
launch_runs synth_vga_only -jobs 4
wait_on_run synth_vga_only
launch_runs impl_vga_only -to_step write_bitstream -jobs 4
wait_on_run impl_vga_only
```

VGA-only bitstream 通常在：

```text
vivado_build/fpga_vision_system.runs/impl_vga_only/vga_only_top.bit
```

运行完整摄像头工程：

```tcl
launch_runs synth_vision_top -jobs 4
wait_on_run synth_vision_top
launch_runs impl_vision_top -to_step write_bitstream -jobs 4
wait_on_run impl_vision_top
```

完整工程 bitstream 通常在：

```text
vivado_build/fpga_vision_system.runs/impl_vision_top/vision_top.bit
```

如果某个 run 已经跑过，修改 RTL 或 XDC 后需要先重置：

```tcl
reset_run synth_vga_only
reset_run impl_vga_only
```

或：

```tcl
reset_run synth_vision_top
reset_run impl_vision_top
```

### 5.2 GUI 手动建立方式

在 Vivado 左侧 Sources 面板中：

```text
1. Add Sources -> Add or Create Design Sources
2. 添加 rtl/vga_only_top.v
3. 确认 rtl/vga_timing.v 已经在工程中
```

建立 VGA-only 约束集合：

```text
1. Add Sources -> Add or Create Constraints
2. Create File 或 Add Files
3. 添加 constraints/vga_only_ego1.xdc
4. 建议约束集合命名为 constrs_vga_only
```

建立完整工程约束集合：

```text
1. 确认 constraints/ego1_template.xdc 单独属于完整工程约束集合
2. 建议约束集合命名为 constrs_vision
```

在 Design Runs 窗口中：

```text
1. 右键空白处或使用 Flow -> Create Runs
2. 创建 Synthesis Run: synth_vga_only
3. Constraints Set 选择 constrs_vga_only
4. 创建 Implementation Run: impl_vga_only
5. Parent Synthesis Run 选择 synth_vga_only
```

创建完成后，在 Tcl Console 设置该 run 的顶层：

```tcl
set_property STEPS.SYNTH_DESIGN.ARGS.TOP vga_only_top [get_runs synth_vga_only]
```

同理，为完整工程建立：

```text
Synthesis Run: synth_vision_top
Implementation Run: impl_vision_top
Constraints Set: constrs_vision
Parent Run: synth_vision_top
```

并设置完整工程顶层：

```tcl
set_property STEPS.SYNTH_DESIGN.ARGS.TOP vision_top [get_runs synth_vision_top]
```

如果 Vivado 2017.4 报 `The object 'run' does not have a property 'STEPS.SYNTH_DESIGN.ARGS.TOP'`，不要继续使用上面两条 `STEPS.SYNTH_DESIGN.ARGS.TOP` 命令。改为：

```tcl
set_property top vga_only_top [get_filesets sources_vga_only]
set_property top vision_top [get_filesets sources_1]
```

然后分别右键 run：

```text
synth_vga_only  -> Launch Runs
impl_vga_only   -> Launch Runs to Generate Bitstream

synth_vision_top -> Launch Runs
impl_vision_top  -> Launch Runs to Generate Bitstream
```

注意：不要让 `vga_only_ego1.xdc` 和 `ego1_template.xdc` 同时作用于同一个 run。两者顶层端口不同，混用会导致端口找不到、约束错误或错误 bitstream。

## 6. 实物连接和观察

只连接：

```text
EGO1 FPGA 板
VGA 显示器
下载线
电源
```

不要接 OV7670。

烧录后应看到：

```text
test_led 慢速闪烁
VGA 显示器锁定到 640x480
屏幕显示稳定测试图案
拨动 mode_sw[1:0] 后图案变化
按 reset_n 后画面短暂复位并恢复
```

如果这一步通过，说明以下内容基本正确：

```text
100 MHz 系统时钟管脚
复位管脚
VGA RGB 管脚
VGA HSYNC/VSYNC 管脚
VGA 640x480 时序
mode_sw 拨码输入
```

## 6. 故障定位

如果 LED 不闪：

```text
检查 bitstream 是否正确烧录
检查 clk_100m=P17 是否正确
检查 reset_n=P15 是否一直被拉低
检查 test_led=K3 是否对应实际 LED
```

如果 LED 闪但显示器无信号：

```text
优先检查 vga_hsync=D7 和 vga_vsync=C4
检查 VGA 线和显示器输入源
检查显示器是否支持 640x480 VGA
用示波器测 vga_hsync / vga_vsync 是否有周期波形
```

如果有信号但颜色异常：

```text
检查 vga_r/g/b 管脚顺序
检查 VGA 接口或转接线
先使用 mode_sw=00 彩条判断 RGB 通道是否接反
```

如果画面抖动或位置异常：

```text
检查 100 MHz 时钟是否正确
检查 pix_clk 是否约 25 MHz
确认显示器能兼容 25 MHz 近似像素时钟
```

## 8. 通过后的下一步

VGA-only 通过后，再切回完整工程：

```text
顶层模块: vision_top
约束文件: constraints/ego1_template.xdc
```

下一阶段再连接 OV7670，并按以下顺序验证：

```text
1. 测 cam_xclk
2. 测 cam_sioc/cam_siod 初始化波形
3. 测 cam_pclk/cam_href/cam_vsync
4. mode_sw=00 先看灰度图
5. 再验证 Sobel 和素描模式
```
