# MiSans 字体检查与部署

正式抬头纸使用MiSans常规与粗体。中文、英文和数字都应指向正式字体名 `MiSans`，粗体使用相应字重。旧Canva导出中出现的 `MiSans 1`、`MiSans 2` 等名称不作为安装依据。

## 入口
```powershell
& '<技能目录>/scripts/font_preflight.ps1' -Mode Check
& '<技能目录>/scripts/font_preflight.ps1' -Mode Ensure -AcceptLicense
```
Check只读。Ensure在检查已安装字体后，仅部署缺失字重。`-AcceptLicense` 仅在使用者已阅读并接受小米许可时提供，不能由助手代为接受；没有许可确认时报告 `license_required` 并给出官网入口。默认按当前Windows用户安装，无需改动其他用户字体。

官方下载与许可入口为 https://hyperos.mi.com/font/zh/download/ 。官方字体包地址记录于 `assets/font_sources.json`，执行时检查HTTPS及官方域名。若地址失效，停止下载并报告 `download_failed`，经核验后更新地址。也可使用自己从官网获得并已解压的字库目录，通过 `-FontDirectory <目录>` 指定。

安装仅处理MiSans-Regular与MiSans-Bold，公开技能包不附带字体文件。许可原文以官网下载页面提供的当前协议为准，不修改字体或将字体单独重新分发。

脚本核对注册项、字体文件与系统可见字体。文件名、内部字体名、可用字重不一致时报告缺口。已安装字体不覆盖；文件冲突、权限拒绝或登记失败时记录具体阶段。回滚本次新增的文件和注册项，保留此前已有安装。重新执行会先检查现状，避免重复安装。

安装后广播字体变更通知，重新检查状态。正在运行的Word/WPS可能缓存字体，只提示使用者保存工作并重新打开应用，不擅自关闭用户文档。实际渲染后用PDF字体名称验证，注册成功不等于排版验证完成。

脚本输出JSON。`ready` 表示文件、注册记录及系统字体可见性检查通过；渲染字体是否正确另看生成记录与PDF验收。网络、许可、权限或环境受限时保留原因，不默认换成宋体、微软雅黑后声称MiSans已经部署。

非Windows环境先检查实际字体及渲染工具。此版本自动安装脚本仅覆盖Windows，不声称已完成macOS、Linux或云端安装。WorkBuddy、ZCode是否允许脚本执行取决于实际客户端权限，仅导入技能ZIP不等于脚本已运行。
