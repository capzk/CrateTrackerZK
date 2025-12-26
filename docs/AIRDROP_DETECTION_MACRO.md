# 空投检测宏命令

## 检测当前地图的空投箱子

### 推荐版本（已验证可用）

```lua
/run local v=C_VignetteInfo.GetVignettes();local c=0;for _,g in ipairs(v)do local n=C_VignetteInfo.GetVignetteInfo(g).name;if n=="战争物资箱"or n=="War Supply Crate"then c=c+1 end end;print(c>0 and"发现"..c.."个空投"or"未发现空投")
```

---

## 使用方法

1. 在游戏中按 `ESC` → `宏命令设置`
2. 点击 `新建`，输入宏名称（如：`检测空投`）
3. **完整复制**上面的代码（包括 `/run`），粘贴到宏命令框中
4. 点击 `确定`，将宏拖到动作条上
5. 点击宏按钮执行

**注意**：复制时确保代码完整，不要有换行或截断。

---

**创建日期**: 2024年
