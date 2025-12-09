# 🚀 遊戲統計數據導入 - 使用說明

## 最簡單的方式 - 一行命令

### 第一步：獲取 Token

在 Discord 執行：
```
/生成上傳令牌
```

### 第二步：執行導入命令

在 **PowerShell** 中執行（複製整行，替換 YOUR_USERNAME 和 YOUR_REPO）：

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/scripts/import.ps1 | iex -Token "YOUR_TOKEN" -Uid "YOUR_UID"
```

**替換內容：**
- `YOUR_USERNAME` → GitHub 用戶名
- `YOUR_REPO` → 倉庫名稱
- `YOUR_TOKEN` → 從 Discord 獲取的 Token
- `YOUR_UID` → 您的遊戲 UID

### 第三步：查看統計

在 Discord 執行：
```
/遊戲統計
```

## 💡 交互式方式（推薦新手）

如果不想在命令中輸入參數：

```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/scripts/import.ps1 | iex
```

然後按提示輸入 Token 和 UID。

## ⚠️ 首次使用

如果是第一次使用 PowerShell 腳本，可能需要設置執行策略：

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

執行後選擇 `Y` 確認。

## ✅ 優勢

- ✅ **無需下載任何文件** - 直接從 GitHub 執行
- ✅ **完全自動化** - 自動查找遊戲數據庫
- ✅ **一行命令** - 最簡單的使用方式
- ✅ **API 自動配置** - 使用 `https://fukuroapi.fulin-net.top`

## 📝 完整示例

假設：
- GitHub: `https://github.com/username/ww_bot`
- Token: `abc123def456...`
- UID: `710596960`

執行命令：
```powershell
iwr -UseBasicParsing https://raw.githubusercontent.com/username/ww_bot/main/scripts/import.ps1 | iex -Token "abc123def456..." -Uid "710596960"
```

## 🆘 常見問題

### 問題 1：無法執行腳本

**錯誤**：`無法載入檔案，因為這個系統上已停用指令碼執行`

**解決**：
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 問題 2：找不到數據庫

**解決**：確認已安裝 WutheringWavesTool 並使用它啟動過遊戲

### 問題 3：Token 無效

**解決**：重新在 Discord 生成新 Token（Token 有效期 30 分鐘，只能使用一次）

---

**就是這麼簡單！** 🎉

