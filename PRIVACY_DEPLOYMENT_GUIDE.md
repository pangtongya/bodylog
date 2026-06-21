# FormLog 隐私政策部署指南

## 📁 已创建的文件

**文件位置**：`/Users/pangtong/BodyLog/privacy-policy.html`

**特点**：
- ✅ 简洁专业（只有1个HTML文件，无外部依赖）
- ✅ 完整内容（10个章节）
- ✅ 响应式设计（支持手机和电脑）
- ✅ 强调"隐私优先"理念

---

## 🚀 手动部署步骤（3分钟）

### 步骤1：创建GitHub仓库

1. 访问 https://github.com/new
2. **Repository name**: `formlog-privacy`
3. 选择 **Public**
4. ✅ 勾选 "Add a README file"
5. 点击 **Create repository**

### 步骤2：上传隐私政策文件

1. 进入刚创建的仓库页面
2. 点击 **Add file** → **Upload files**
3. 上传文件：`/Users/pangtong/BodyLog/privacy-policy.html`
4. **Commit message**: `Add privacy policy`
5. 点击 **Commit changes**

### 步骤3：启用GitHub Pages

1. 进入仓库 **Settings**
2. 左侧菜单点击 **Pages**
3. **Source**: 选择 "Deploy from a branch"
4. **Branch**: 选择 `main` 和 `/ (root)`
5. 点击 **Save**
6. 等待1-2分钟

### 步骤4：验证

访问：`https://pangtongya.github.io/formlog-privacy/privacy-policy.html`

应该看到FormLog的隐私政策页面。

---

## 🔧 如果遇到问题

### 问题1：GitHub Pages不工作

**解决方案**：
1. 检查仓库是否为Public
2. 检查分支名称是否为`main`
3. 等待5-10分钟（GitHub Pages需要时间部署）

### 问题2：页面显示404

**解决方案**：
1. 确认文件名是否为`privacy-policy.html`
2. 确认文件已在`main`分支
3. 清除浏览器缓存重试

---

## ✅ 完成后

隐私政策URL将可以正常访问：
```
https://pangtongya.github.io/formlog-privacy/privacy-policy.html
```

这个URL已经在FormLog代码中正确设置，用户点击"隐私政策"时会打开这个页面。

---

## 📝 文件内容摘要

**隐私政策包含**：
1. 数据收集（我们不收集任何数据）
2. 数据存储（只存在本地）
3. 数据导出和备份
4. 购买和订阅（使用StoreKit 2）
5. 照片权限
6. 通知权限
7. 儿童隐私
8. 隐私政策的变更
9. 联系我们
10. 生效日期

**核心承诺**：隐私优先，数据只存在你的手机，不上云
