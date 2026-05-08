## [ERR-20260508-001] dotnet_build_after_workload_restore

**Logged**: 2026-05-08T13:55:03+08:00
**Priority**: low
**Status**: resolved
**Area**: tests

### Summary
`dotnet workload restore` 成功后，项目构建仍可能因缺少 `project.assets.json` 在 `--no-restore` 下失败。

### Error
```text
error NETSDK1004: 找不到资产文件“...\obj\project.assets.json”。运行 NuGet 包还原以生成此文件。
```

### Context
- 先执行 `dotnet workload restore .\src\MyItems\MyItems.csproj` 安装 MAUI workload。
- 随后立即执行 `dotnet build .\src\MyItems\MyItems.csproj -f net10.0-windows10.0.19041.0 --no-restore`。

### Suggested Fix
在 workload restore 后执行一次项目级 NuGet restore，再使用 `--no-restore` 构建：
```powershell
dotnet restore .\src\MyItems\MyItems.csproj -p:TargetFramework=net10.0-windows10.0.19041.0
dotnet build .\src\MyItems\MyItems.csproj -f net10.0-windows10.0.19041.0 --no-restore
```

### Metadata
- Reproducible: yes
- Related Files: src/MyItems/MyItems.csproj

### Resolution
- **Resolved**: 2026-05-08T13:55:03+08:00
- **Notes**: 已通过项目级 restore 生成资产文件，随后 Windows target 构建通过。

---
