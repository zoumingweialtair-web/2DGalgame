# 2DGalGame

计划使用 Godot 制作的二次元放置陪伴游戏。角色在不同景色中与玩家自然对视，重点是安静的陪伴感。

现已包含可运行的 Godot 4.6 雪夜阳台循环动画原型。

## 动画预览

- [12 秒循环 GIF](previews/snow-night-loop.gif)
- [1280 × 720 / 30 FPS 视频](previews/snow-night-loop.mp4)
- [自动循环播放器](previews/index.html)：在浏览器打开此本地文件。

使用用户指定的蓝发金瞳、白外套原画，包含分层飘雪、17 处远景信号灯闪烁、8 扇右侧近景窗户错峰亮灭、头发与围巾随风轻摆、自然眨眼、胸口呼吸微动和周期性呼气白雾。所有效果共享 12 秒循环时间轴。

当前第三版让右侧近景窗户真正呈现可见的开关灯变化：0.45–0.65 秒过渡，随后保持数秒亮态或暗态；保留窗框与建筑结构，信号灯也有明确的亮暗状态。第二版的小幅调光版本保留在 `previews/` 供对比。眨眼维持 0.68 秒（闭合 0.22 秒、停留 0.12 秒、睁开 0.34 秒），每轮两次。

## 运行与导出

用 Godot 4.6 打开 `project.godot`，按 F6/F5 运行；也可在仓库根目录执行 `godot --path .`。空格暂停，R 重播，F 切换全屏，Esc 退出。

安装 Godot 和 FFmpeg 后，运行 `bash tools/render_preview.sh` 可重新导出 MP4 与无限循环 GIF。视频不带音频。Linux 云端导出需要可用的 X11 显示和 OpenGL 渲染，不能用 `--headless` 替代实际画面渲染。本次已在 Xorg dummy 显示 `:91` 上使用 Mesa 软件渲染验证：

```bash
DISPLAY=:91 LIBGL_ALWAYS_SOFTWARE=1 bash tools/render_preview.sh
```

`assets/animation/` 保存原图和闭眼辅助帧；`shaders/portrait.gdshader` 负责局部风动与眼部合成；`scripts/ambient.gd` 负责飘雪和呼气；`scripts/city_lights.gd` 负责城市灯光。该原型采用原画局部形变及合成，未进行完整角色骨骼绑定；原图已有的雪点仍是画面的一部分。

## 美术资料

- [美术方向与方案索引](art/concepts/README.md)
- [已认可的城市夜景半身构图](art/concepts/approved/balcony-city-night.png)
- [最新五个年代感风格方案](art/concepts/style-options/)
- [早期场景及构图探索](art/concepts/archive/)

`art/concepts/` 保留早期年代感方案，供历史参考。当前动画采用后续选定的柔光雪夜原画，见 `assets/animation/balcony_open.png`。
