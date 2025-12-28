# 分支管理指南

## 分支说明

### main 分支（正式版）
- **用途**：正式发布版本
- **版本号格式**：`x.y.z`（如：`1.0.6`）
- **要求**：
  - 版本号必须是纯数字格式（x.y.z）
  - 不能包含 `-dev`, `-alpha`, `-beta` 等后缀
  - 代码必须经过测试，稳定可用
- **发布**：GitHub Actions 会自动检测版本号变化并创建 Release

### dev 分支（开发版）
- **用途**：开发测试版本
- **版本号格式**：`x.y.z-dev`（如：`1.0.6-dev`）
- **要求**：
  - 版本号必须包含 `-dev` 后缀
  - 用于开发、测试新功能
  - 不自动发布 Release
- **发布**：不会触发 GitHub Actions 自动发布

## 版本号规范

### 正式版本号（main 分支）
```
## Version: 1.0.6
```
- ✅ 正确格式：`1.0.6`, `1.1.0`, `2.0.0`
- ❌ 错误格式：`1.0.6-dev`, `1.0.6-alpha`, `1.0.6-beta`

### 开发版本号（dev 分支）
```
## Version: 1.0.6-dev
```
- ✅ 正确格式：`1.0.6-dev`, `1.0.7-dev`, `1.1.0-dev`
- ❌ 错误格式：`1.0.6`（开发版必须带后缀）

## 工作流程

### 开发新功能
1. 在 `dev` 分支开发
2. 版本号设置为 `x.y.z-dev`（如：`1.0.7-dev`）
3. 提交并推送到 `dev` 分支
4. 测试功能

### 发布正式版
1. 将 `dev` 分支合并到 `main` 分支
2. 修改版本号为正式版本号（移除 `-dev` 后缀）
3. 更新所有文件中的版本号：
   - `CrateTrackerZK.toc`
   - `InfoText.lua`
   - `README.md`
4. 提交并推送到 `main` 分支
5. GitHub Actions 自动检测版本变化并创建 Release

## 示例

### 开发阶段（dev 分支）
```bash
git checkout dev
# 修改代码...
# 更新版本号
echo "## Version: 1.0.7-dev" > CrateTrackerZK.toc
git add .
git commit -m "开发新功能"
git push origin dev
```

### 发布阶段（main 分支）
```bash
git checkout main
git merge dev
# 更新版本号为正式版本
echo "## Version: 1.0.7" > CrateTrackerZK.toc
# 更新 InfoText.lua 和 README.md
git add .
git commit -m "发布 v1.0.7"
git push origin main
# GitHub Actions 自动创建 Release
```

## GitHub Actions 检查

工作流会自动检查：
1. ✅ 当前分支是否为 `main`
2. ✅ 版本号格式是否为 `x.y.z`（纯数字）
3. ✅ 版本号是否包含开发后缀（如有则拒绝）
4. ✅ 版本号是否发生变化

只有通过所有检查，才会创建 Release。

