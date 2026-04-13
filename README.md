# Unity Ice Shader

## 简介

基于 Unity Built-in 渲染管线开发的程序化冰块着色器，实现折射、菲涅尔、内部白雾等视觉效果。

## 效果特性

- **折射**：基于法线扰动的 GrabPass 折射，模拟冰的透视变形
- **菲涅尔**：边缘反射增强，表现冰面光泽
- **内部白雾**：可控位置与形状（球形/盒形）的体积感白雾层
- **裂纹细节**：叠加裂纹贴图，影响折射强度与透明度
- **边缘光**：可调色的 Rim 发光效果

## 文件结构

```
ICE/
├── mat/      # 材质文件
├── Mesh/     # 网格文件
├── shader/   # Shader 源文件
└── tex/      # 贴图文件
```


## 使用方法

1. 将整个 `ICE` 文件夹导入 Unity 项目 Assets 目录
2. 在材质面板选择 `Custom/IceShader_EnhancedWhiteFog`
3. 调整参数：
   - `Fog Center Position` 控制内部白雾位置
   - `Fog Size` 控制雾的范围
   - `Fog Shape` 0 为球形，1 为盒形

## 开发环境

- Unity Built-in 渲染管线
- HLSL / CG Shader
