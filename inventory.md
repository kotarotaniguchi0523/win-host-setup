# Inventory — Windows ホストのグローバル導入（完全版・全一覧）

収集: 2026-10-13〜15 / 場所: `C:\Users\%USERNAME%\win-host-setup`
対象: **Windows 本体のグローバル導入のみ**（プロジェクトローカル、エディタ/ブラウザ拡張は対象外）。
目標: **mise へ統一**（Python `3.14` / Node `26` / Go `1.27` / `hk`）。手順は `PLAN.md`、移行分析は `migration-npm.md`/`migration-pip.md`。

## 0. 重要な訂正

`Get-Command` が (none) でも **PATH 未通過なだけ**で実体があるもの:

- **Rust** — `~/.cargo/bin`（cargo/rustc/rustup/clippy/rustfmt/rust-analyzer/rls/miri/gdb/lldb…）＋ toolchain `stable-x86_64-pc-windows-msvc`
- **uv** — `~/.local/bin`（`uv`, `uvx`, `uvw`）＋ **`claude.exe`**（Claude Code CLI）。uv tool は無し
- **mise** — `…\WinGet\Packages\jdx.mise_…\mise\bin\mise.exe`（既に使用中）
- **Go** — toolchain 無し（`~/go/bin/gopls.exe` の残骸のみ）

## 1. mise（既存設定・実体）

`~/.config/mise/config.toml`:

```toml
[tools]
betterleaks            = "1.9.0"
node                   = "26.11.1"
python                 = "3.14.8"
gh                     = "2.102.0"
doppler                = "3.76.0"
"github:microsoft/apm" = "0.14.0"
"aqua:k1LoW/mo"        = "1.5.5"
"github:microsoft/waza" = "0.33.0"
rtk                    = "0.40.0"
pnpm                   = "12.12.1"
uv                     = "0.13.0"
go                     = "1.27.2"
"aqua:jj-vcs/jj"       = "0.46.0"
hk                     = "2.6.0"
jq                     = "1.8.2"
ripgrep                = "15.2.0"
npm = "12.2.0"

[settings]
paranoid            = true
locked              = true
locked_verify_provenance = true
minimum_release_age = "2d"
pin                 = true

[settings.npm]
package_manager = "pnpm"

[env]
PIP_INDEX_URL = "https://pypi.flatt.tech/simple/"
UV_INDEX_URL  = "https://pypi.flatt.tech/simple/"
NPM_CONFIG_REGISTRY = "https://npm.flatt.tech/"
```

**mise installs（実体）**:
- aqua-jj-vcs-jj@0.46.0
- aqua-k1-lo-w-mo@1.5.5
- betterleaks@1.9.0
- doppler@3.76.0
- gh@2.102.0
- github-microsoft-apm@0.14.0
- github-microsoft-waza@0.33.0
- go@1.27.2
- hk@2.6.0
- jq@1.8.2
- node@26.11.1
- npm@12.2.0
- pnpm@12.12.1
- python@3.14.8
- ripgrep@15.2.0
- rtk@0.40.0
- uv@0.13.0

**mise shims（.exe）**:
- apm
- betterleaks
- doppler
- gh
- go
- gofmt
- hk
- install_tools
- jj
- jq
- mo
- node
- nodevars
- npm
- npx
- pip
- pip3
- pn
- pnpm
- pnpx
- pnx
- python
- python3
- pythonw
- rg
- rtk
- uv
- uvw
- uvx
- waza

## 2. パッケージマネージャ別（全一覧）

### 2.1 winget — export 可能（77）

`winget export` の PackageIdentifier:

```
CoreyButler.NVMforWindows
Docker.DockerDesktop
Git.Git
HeidiSQL.HeidiSQL
Maxon.Cinema4D.2024
Microsoft.Office
Microsoft.OneDrive
ShiningLight.OpenSSL.Light
UniversityOfWaikato.Weka
Zen-Team.Zen-Browser
ProcessingFoundation.Processing
GitHub.cli
Google.JapaneseIME
Oracle.MySQL
Google.GoogleDrive
RedHat.Podman
Oracle.MySQLShell
Logitech.OptionsPlus
Oracle.MySQLWorkbench
Google.Chrome.Dev.EXE
Microsoft.Edge
OBSProject.OBSStudio
Microsoft.VCRedist.2013.x64
Microsoft.DotNet.DesktopRuntime.6
Microsoft.PowerShell
Microsoft.VCRedist.2015+.x86
Microsoft.DotNet.DesktopRuntime.8
Microsoft.DotNet.DesktopRuntime.7
Microsoft.DotNet.DesktopRuntime.9
Microsoft.DotNet.AspNetCore.7
Microsoft.Teams.Classic
Docker.sbx
Microsoft.VCRedist.2015+.x64
ETHZurich.SafeExamBrowser
Microsoft.DotNet.Runtime.6
MAMP.MAMP
Python.Launcher
Microsoft.DotNet.DesktopRuntime.10
Microsoft.DotNet.Runtime.5
Microsoft.VCRedist.2012.x64
VoyagerX.Vrew
Amazon.Kindle
Betterleaks.Betterleaks
GitHub.Copilot
Google.CloudSDK
Rustlang.Rustup
Zoom.Zoom.EXE
evilmartians.lefthook
DeepL.DeepL
Inkdrop.Inkdrop
jdx.mise
SlackTechnologies.Slack
Microsoft.VisualStudioCode.Insiders
ZedIndustries.Zed
Python.Python.3.13
Microsoft.VisualStudioCode
Anysphere.Cursor
Canonical.Ubuntu
Microsoft.Teams
Microsoft.AppInstaller
Microsoft.DotNet.Native.Runtime
Microsoft.Outlook
Microsoft.UI.Xaml.2.7
Microsoft.UI.Xaml.2.8
Microsoft.VCLibs.Desktop.14
Microsoft.VCLibs.14
Microsoft.WindowsAppRuntime.1.1
Microsoft.WindowsAppRuntime.1.2
Microsoft.WindowsAppRuntime.1.3
Microsoft.WindowsAppRuntime.1.4
Microsoft.WindowsAppRuntime.1.5
Microsoft.WindowsAppRuntime.1.6
Microsoft.WindowsAppRuntime.1.7
Microsoft.WindowsAppRuntime.1.8
Microsoft.WindowsAppRuntime.2
Microsoft.WindowsTerminal
Microsoft.WSL
```

### 2.2 winget list（全 275 / Store・ARP 含む）

| Name | Id | Version |
|---|---|---|
| Amazon Kindle | Amazon.Kindle | 2.8.0.70980 |
| App Installer | Microsoft.AppInstaller | 1.29.380.0 |
| AV1 Video Extension | MSIX\Microsoft.AV1VideoExtension_2.0.35.0_x64__8wekyb3d8bbwe | 2.0.35.0 |
| AVC Encoder Video Extension | MSIX\Microsoft.AVCEncoderVideoExtension_1.1.47.0_x64__8wekyb3d8bbwe | 1.1.47.0 |
| BUFFALO エアステーション設定ツール | ARP\Machine\X86\BUFFALO_AirSet2_is1 | 2.1.2 |
| Canon IJ Network Scanner Selector EX2 | ARP\Machine\X86\Canon_IJ_Network_Scanner_Selector_EX2 | 2.0.15.2 |
| Canon IJ Printer Assistant Tool | ARP\Machine\X86\Canon IJ Printer Assistant Tool | 1.61.1.10 |
| Canon IJ Scan Utility | ARP\Machine\X86\Canon_IJ_Scan_Utility | 1.6.0.2 |
| Canon Inkjet Print Utility | MSIX\34791E63.CanonInkjetPrintUtility_3.1.0.0_neutral__6e5tt8cgb93ep | 3.1.0.0 |
| Canon TS8430 series Driver | ARP\Machine\X64\{1199FAD5-9546-44F3-81CF-FFDB8040B7BF}_Canon_TS8430_series | 1.05 |
| ChatGPT | MSIX\OpenAI.Codex_26.1007.2314.0_x64__2p2nqsd0c76g0 | 26.1007.2314.0 |
| cloudflared | Cloudflare.cloudflared | 2026.10.0 |
| Command Palette | MSIX\Microsoft.CommandPalette_0.11.11762.0_x64__8wekyb3d8bbwe | 0.11.11762.0 |
| Copilot CLI | GitHub.Copilot | 0.0.368 |
| Cursor (User) | Anysphere.Cursor | 3.5.17 |
| DeepL | DeepL.DeepL | Unknown |
| Dell CinemaColor | MSIX\PortraitDisplays.DellCinemaColor_2.4.78.0_x64__2dgmkzkw4h30c | 2.4.78.0 |
| Dell Connected Service Delivery | ARP\Machine\X64\{7C805313-D942-4846-8FAD-F84F03256AF2} | 1.1.2.0 |
| Dell Core Services | ARP\Machine\X64\{B5761B5C-03DF-4A7A-81AD-94F8D4D2C4EA} | 1.10.50.0 |
| Dell Customer Connect | MSIX\DellInc.DellCustomerConnect_5.5.5.0_x64__htrsf667h5kn2 | 5.5.5.0 |
| Dell Digital Delivery | MSIX\DellInc.DellDigitalDelivery_5.6.3.0_x64__htrsf667h5kn2 | 5.6.3.0 |
| Dell Digital Delivery Services | ARP\Machine\X86\{87310396-FD49-4108-BBBB-28E1C3EA85E9} | 5.6.3.0 |
| Dell Mobile Connect | MSIX\ScreenovateTechnologies.DellMobileConnectPlus_4.1.8330.0_x64__0vhbc3ng4wbp0 | 4.1.8330.0 |
| Dell Mobile Connect Driver | ARP\Machine\X64\{6F9CB82D-BC34-4FC1-B90D-AFFAC5C85E7B} | 4.1.7498 |
| Dell SupportAssist | ARP\Machine\X64\{65043213-393F-49BF-B658-5B06C5F713FF} | 5.2.1.2141 |
| Dell SupportAssist for PCs | MSIX\DellInc.DellSupportAssistforPCs_5.2.1.0_x64__htrsf667h5kn2 | 5.2.1.0 |
| Dell SupportAssist OS Recovery Plugin for Dell Update | ARP\Machine\X86\{454ee07e-5b78-4cbe-ada0-ca0733b60af8} | 5.5.16.3 |
| Dell SupportAssist Remediation | ARP\Machine\X86\{400b816d-1b36-426f-9595-5742bfd07ec4} | 5.5.16.3 |
| Dell Update | MSIX\DellInc.DellUpdate_5.5.23.0_x86__htrsf667h5kn2 | 5.5.23.0 |
| Dell Update for Windows Universal | ARP\Machine\X64\{1405CADB-1E91-4C4E-AC9E-00B733563560} | 5.5.0 |
| Delta | ARP\User\X64\{1C577439-7DF7-4699-84D7-6A8E7189EA97} | 0.19.2 |
| Discord | ARP\User\X64\Discord | 1.0.9261 |
| Docker Desktop | Docker.DockerDesktop | 4.94.0 |
| Docker Sandboxes | Docker.sbx | 0.47.0 |
| English (United States) Local Experience Pack | MSIX\Microsoft.LanguageExperiencePacken-US_26100.143.158.0_neutral__8wekyb3d8bbwe | 26100.143.158.0 |
| f.lux | MSIX\F.luxSoftwareLLC.f.lux_4.137.0.0_x86__sw1dyjdkns7gt | 4.137.0.0 |
| fd | sharkdp.fd | 10.5.0 |
| Feedback Hub | MSIX\Microsoft.WindowsFeedbackHub_2.2608.303.0_x64__8wekyb3d8bbwe | 2.2608.303.0 |
| FortiClient VPN | ARP\Machine\X64\{15C7B361-A0B2-4E79-93E0-868B5000BA3F} | 7.4.3.1790 |
| Fusion Service | ARP\Machine\X86\{6e578348-d226-4341-a69f-26274feac293} | 2.2.14.0 |
| Game Bar | MSIX\Microsoft.XboxGamingOverlay_7.326.8061.0_x64__8wekyb3d8bbwe | 7.326.8061.0 |
| Game Speech Window | MSIX\Microsoft.XboxSpeechToTextOverlay_1.97.17002.0_x64__8wekyb3d8bbwe | 1.97.17002.0 |
| Get Help | MSIX\Microsoft.GetHelp_10.2409.42492.0_x64__8wekyb3d8bbwe | 10.2409.42492.0 |
| Git | Git.Git | 2.54.0 |
| Gmail | ARP\User\X64\05c14bf9ba272051ceac8f8cbc87856f | 1.0 |
| Gmail | ARP\User\X64\f41153b2464c682cff545deb86ec5799 | 1.0 |
| Google Chrome | ARP\Machine\X86\Google Chrome | 155.0.8059.40 |
| Google Chrome Dev | Google.Chrome.Dev.EXE | 157.0.8092.0 |
| Google Cloud SDK | Google.CloudSDK | Unknown |
| Google Drive | Google.GoogleDrive | 132.0.0.0 |
| Google Keep | ARP\User\X64\d3d6904544405551ce7ff692374b8940 | 1.0 |
| Google カレンダー | ARP\User\X64\39fa2b3f5bbdfd5f5ee981c244fc9fbd | 1.0 |
| Google ドライブ | ARP\User\X64\0425bd0075635e8f79198bb588a7b1c0 | 1.0 |
| Google パスワード マネージャー | ARP\User\X64\733345c6a1a8847f7306bf24d1279b84 | 1.0 |
| Google 日本語入力 | Google.JapaneseIME | 3.34.6260.0 |
| HeidiSQL 12.17.0.7270 | HeidiSQL.HeidiSQL | 12.17.0.7270 |
| HEIF Image Extension | MSIX\Microsoft.HEIFImageExtension_1.2.48.0_x64__8wekyb3d8bbwe | 1.2.48.0 |
| HEVC Video Extensions from Device Manufacturer | MSIX\Microsoft.HEVCVideoExtension_2.5.33.0_x64__8wekyb3d8bbwe | 2.5.33.0 |
| Ink.Handwriting.ja-JP.1.0 | MSIX\Microsoft.Ink.Handwriting.ja-JP.1.0_0.1248.2215.0_x64__8wekyb3d8bbwe | 0.1248.2215.0 |
| Ink.Handwriting.ja-JP.1.0 | MSIX\Microsoft.Ink.Handwriting.ja-JP.1.0_0.1377.316.0_x86__8wekyb3d8bbwe | 0.1377.316.0 |
| Ink.Handwriting.Main.ja-JP.1.0 | MSIX\Microsoft.Ink.Handwriting.Main.ja-JP.1.0_0.1248.2215.0_x64__8wekyb3d8bbwe | 0.1248.2215.0 |
| inkdrop | Inkdrop.Inkdrop | 5.11.9 |
| Installing stagewise (Pre-Release)... | ARP\User\X64\stagewise-prerelease | 1.0.0-alpha087 |
| Intel(R) C++ Redistributables on Intel(R) 64 | ARP\Machine\X86\{F70BCE36-25F2-4475-A918-6209B3D85BF3} | 15.0.179 |
| Intel(R) Graphics Software & Drivers | ARP\Machine\X64\Intel(R) Graphics Software & Drivers | 1.0.1168.2 |
| Intel(R) Management Engine Components | ARP\Machine\X64\{1CEAC85D-2590-4760-800F-8DE5E91F3700} | 2345.5.42.0 |
| Intel(R) Serial IO | ARP\Machine\X64\{9FD91C5C-44AE-4D9D-85BE-AE52816B0294} | 30.100.2104.1 |
| Intel® Graphics Command Center | MSIX\AppUp.IntelGraphicsExperience_1.100.5688.0_x64__8j3eq9eme6ctt | 1.100.5688.0 |
| Intel® Graphics Software | MSIX\AppUp.IntelArcSoftware_26.32.2604.0_x64__8j3eq9eme6ctt | 26.32.2604.0 |
| Intel® OptaneTM Memory and Storage Management | MSIX\AppUp.IntelOptaneMemoryandStorageManagement_18.1.1042.0_x64__8j3eq9eme6ctt | 18.1.1042.0 |
| KWIC Concordance | ARP\Machine\X86\{37488C5F-1729-4559-9E71-5717013B6627} | 5.4.0 |
| LINE | ARP\User\X64\LINE | 9.1.2.3379 |
| LINE | MSIX\LINE_9.14.0.0_neutral__x486b4ff3yryg | 9.14.0.0 |
| Local AI Manager for Microsoft 365 | MSIX\aimgr_0.20.62.0_x64__8wekyb3d8bbwe | 0.20.62.0 |
| Logi Download Assistant | ARP\Machine\X86\LogiDownloadAssistant | 2.0.1020 |
| Logi Options+ | Logitech.OptionsPlus | 2.9.984725 |
| Logi Plugin Service | ARP\Machine\X64\{704B6BE1-0C4F-4DCF-AF1C-345E5A7CB182} | 6.4.2.3414 |
| Mail and Calendar | MSIX\microsoft.windowscommunicationsapps_16005.14326.22342.0_x64__8wekyb3d8bbwe | 16005.14326.22342.0 |
| MAMP & MAMP PRO version 5.0.5 | MAMP.MAMP | 5.0.5 |
| Maxon Cinema 4D 2024 | Maxon.Cinema4D.2024 | 2024 |
| Meltype | ARP\User\X64\Meltype_is1 | 1.2.1 |
| Microsoft .Net Native Framework Package 1.2 | MSIX\Microsoft.NET.Native.Framework.1.2_1.2.23231.0_x64__8wekyb3d8bbwe | 1.2.23231.0 |
| Microsoft .Net Native Framework Package 1.2 | MSIX\Microsoft.NET.Native.Framework.1.2_1.2.23231.0_x86__8wekyb3d8bbwe | 1.2.23231.0 |
| Microsoft .Net Native Framework Package 2.1 | MSIX\Microsoft.NET.Native.Framework.2.1_2.1.27427.0_x64__8wekyb3d8bbwe | 2.1.27427.0 |
| Microsoft .Net Native Framework Package 2.1 | MSIX\Microsoft.NET.Native.Framework.2.1_2.1.27427.0_x86__8wekyb3d8bbwe | 2.1.27427.0 |
| Microsoft .Net Native Framework Package 2.2 | MSIX\Microsoft.NET.Native.Framework.2.2_2.2.29512.0_x64__8wekyb3d8bbwe | 2.2.29512.0 |
| Microsoft .Net Native Framework Package 2.2 | MSIX\Microsoft.NET.Native.Framework.2.2_2.2.29512.0_x86__8wekyb3d8bbwe | 2.2.29512.0 |
| Microsoft .Net Native Runtime Package 1.1 | MSIX\Microsoft.NET.Native.Runtime.1.1_1.1.23406.0_x64__8wekyb3d8bbwe | 1.1.23406.0 |
| Microsoft .Net Native Runtime Package 1.1 | MSIX\Microsoft.NET.Native.Runtime.1.1_1.1.23406.0_x86__8wekyb3d8bbwe | 1.1.23406.0 |
| Microsoft .Net Native Runtime Package 2.1 | MSIX\Microsoft.NET.Native.Runtime.2.1_2.1.26424.0_x64__8wekyb3d8bbwe | 2.1.26424.0 |
| Microsoft .Net Native Runtime Package 2.1 | MSIX\Microsoft.NET.Native.Runtime.2.1_2.1.26424.0_x86__8wekyb3d8bbwe | 2.1.26424.0 |
| Microsoft .Net Native Runtime Package 2.2 | Microsoft.DotNet.Native.Runtime | 2.2.28604.0 |
| Microsoft .Net Native Runtime Package 2.2 | Microsoft.DotNet.Native.Runtime | 2.2.28604.0 |
| Microsoft .NET Runtime - 5.0.17 (x64) | Microsoft.DotNet.Runtime.5 | 5.0.17 |
| Microsoft .NET Runtime - 6.0.36 (x64) | Microsoft.DotNet.Runtime.6 | 6.0.36 |
| Microsoft 365 Apps for enterprise - ja-jp | Microsoft.Office | 16.0.20430.20146 |
| Microsoft 365 companion apps | MSIX\Microsoft.M365Companions_2.2510.30002.0_x64__8wekyb3d8bbwe | 2.2510.30002.0 |
| Microsoft ASP.NET Core 7.0.20 - Shared Framework (x64) | Microsoft.DotNet.AspNetCore.7 | 7.0.20 |
| Microsoft Bing | MSIX\Microsoft.BingSearch_1.1.43.0_x64__8wekyb3d8bbwe | 1.1.43.0 |
| Microsoft Bing Service | ARP\Machine\X86\{289FB81C-CDF9-4B34-AD5E-A21AF980750E} | 2.0.0.8 |
| Microsoft Clipchamp | MSIX\Clipchamp.Clipchamp_4.7.10020.0_x64__yxz26nhyzhsrt | 4.7.10020.0 |
| Microsoft Edge | Microsoft.Edge | 155.0.4283.45 |
| Microsoft Edge | MSIX\Microsoft.MicrosoftEdge.Stable_152.0.4191.53_neutral__8wekyb3d8bbwe | 152.0.4191.53 |
| Microsoft Edge For Game Bar | MSIX\Microsoft.Edge.GameAssist_1.0.4019.0_x64__8wekyb3d8bbwe | 1.0.4019.0 |
| Microsoft Engagement Framework | MSIX\Microsoft.Services.Store.Engagement_10.0.23012.0_x64__8wekyb3d8bbwe | 10.0.23012.0 |
| Microsoft Engagement Framework | MSIX\Microsoft.Services.Store.Engagement_10.0.23012.0_x86__8wekyb3d8bbwe | 10.0.23012.0 |
| Microsoft Family | MSIX\MicrosoftCorporationII.MicrosoftFamily_0.2.40.0_x64__8wekyb3d8bbwe | 0.2.40.0 |
| Microsoft Jenny (Natural) - English (United States) | MSIX\MicrosoftWindows.Voice.en-US.Jenny.1_1.0.8.0_x64__cw5n1h2txyewy | 1.0.8.0 |
| Microsoft OneDrive | Microsoft.OneDrive | 26.178.0913.0007 |
| Microsoft People | MSIX\Microsoft.People_10.2202.100.0_x64__8wekyb3d8bbwe | 10.2202.100.0 |
| Microsoft Photos | MSIX\Microsoft.Windows.Photos_2026.11090.22001.0_x64__8wekyb3d8bbwe | 2026.11090.22001.0 |
| Microsoft Sticky Notes | MSIX\Microsoft.MicrosoftStickyNotes_4.0.6104.0_x64__8wekyb3d8bbwe | 4.0.6104.0 |
| Microsoft Store | MSIX\Microsoft.WindowsStore_22608.1401.6.0_x64__8wekyb3d8bbwe | 22608.1401.6.0 |
| Microsoft Teams | Microsoft.Teams | 26260.1701.5139.3736 |
| Microsoft Teams Meeting Add-in for Microsoft Office | ARP\Machine\X64\{A7AB73A3-CB10-4AA5-9D38-6AEFFBDE4C91} | 1.26.21803 |
| Microsoft To Do | MSIX\Microsoft.Todos_2.178.8571.0_x64__8wekyb3d8bbwe | 2.178.8571.0 |
| Microsoft Update Health Tools | ARP\Machine\X64\{C6FD611E-7EFE-488C-A0E0-974C09EF6473} | 5.72.0.0 |
| Microsoft Visual C++ 2012 Redistributable (x64) - 11.0.61030 Microsoft.VCRedist.2012.x64 | 11.0.61030.0 | winget |
| Microsoft Visual C++ 2013 Redistributable (x64) - 12.0.30501 Microsoft.VCRedist.2013.x64 | 12.0.30501.0 | 12.0.40664.0 |
| Microsoft Visual C++ 2015 UWP Desktop Runtime Package | Microsoft.VCLibs.Desktop.14 | 14.0.33728.0 |
| Microsoft Visual C++ 2015 UWP Desktop Runtime Package | Microsoft.VCLibs.Desktop.14 | 14.0.33728.0 |
| Microsoft Visual C++ 2015 UWP Runtime Package | Microsoft.VCLibs.14 | 14.0.33519.0 |
| Microsoft Visual C++ 2015 UWP Runtime Package | Microsoft.VCLibs.14 | 14.0.33519.0 |
| Microsoft Visual C++ Runtime Package | MSIX\Microsoft.VCLibs.110.00_11.0.51106.1_x64__8wekyb3d8bbwe | 11.0.51106.1 |
| Microsoft Visual C++ Runtime Package | MSIX\Microsoft.VCLibs.110.00_11.0.51106.1_x86__8wekyb3d8bbwe | 11.0.51106.1 |
| Microsoft Visual C++ v14 Redistributable (x64) - 14.50.35719 Microsoft.VCRedist.2015+.x64 | 14.50.35719.0 | 14.51.36247.0 winget |
| Microsoft Visual C++ v14 Redistributable (x86) - 14.50.35719 Microsoft.VCRedist.2015+.x86 | 14.50.35719.0 | 14.51.36247.0 winget |
| Microsoft Visual Studio Code (User) | Microsoft.VisualStudioCode | 1.125.0 |
| Microsoft Visual Studio Code Insiders (User) | Microsoft.VisualStudioCode.Insiders | 1.107.0 |
| Microsoft Visual Studio Setup WMI Provider | ARP\Machine\X86\{E281F6E2-136B-4AF0-895B-253279711697} | 3.7.2182.35401 |
| Microsoft Windows Application Compatibility Fix Database | ARP\Machine\X64\{22221111-1111-1111-1111-111111111111}.sdb | Unknown |
| Microsoft Windows Desktop Runtime - 3.1.22 (x86) | ARP\Machine\X86\{675abf0e-683c-414e-8b1b-9cd40aeb368b} | 3.1.22.30721 |
| Microsoft Windows Desktop Runtime - 6.0.36 (x64) | Microsoft.DotNet.DesktopRuntime.6 | 6.0.36 |
| Microsoft Windows Desktop Runtime - 7.0.20 (x64) | Microsoft.DotNet.DesktopRuntime.7 | 7.0.20 |
| Microsoft Windows Desktop Runtime - 8.0.31 (x64) | Microsoft.DotNet.DesktopRuntime.8 | 8.0.31 |
| Microsoft Windows Desktop Runtime - 9.0.20 (x64) | Microsoft.DotNet.DesktopRuntime.9 | 9.0.20 |
| Microsoft Windows Desktop Runtime 10.0.12 (x64) | Microsoft.DotNet.DesktopRuntime.10 | 10.0.12 |
| Microsoft.Office.ActionsServer | MSIX\Microsoft.Office.ActionsServer_16.0.20430.20146_neutral__8wekyb3d8bbwe | 16.0.20430.20146 |
| Microsoft.UI.Xaml.2.3 | MSIX\Microsoft.UI.Xaml.2.3_2.32002.13001.0_x86__8wekyb3d8bbwe | 2.32002.13001.0 |
| Microsoft.UI.Xaml.2.4 | MSIX\Microsoft.UI.Xaml.2.4_2.42007.9001.0_x64__8wekyb3d8bbwe | 2.42007.9001.0 |
| Microsoft.UI.Xaml.2.4 | MSIX\Microsoft.UI.Xaml.2.4_2.42007.9001.0_x86__8wekyb3d8bbwe | 2.42007.9001.0 |
| Microsoft.UI.Xaml.2.7 | Microsoft.UI.Xaml.2.7 | 7.2409.9001.0 |
| Microsoft.UI.Xaml.2.7 | Microsoft.UI.Xaml.2.7 | 7.2409.9001.0 |
| Microsoft.UI.Xaml.2.8 | Microsoft.UI.Xaml.2.8 | 8.2511.26001.0 |
| Microsoft.UI.Xaml.2.8 | Microsoft.UI.Xaml.2.8 | 8.2501.31001.0 |
| mise-en-place | jdx.mise | 2026.9.18 |
| Mobile devices | MSIX\MicrosoftWindows.CrossDevice_1.26072.116.0_x64__cw5n1h2txyewy | 1.26072.116.0 |
| Movies & TV | MSIX\Microsoft.ZuneVideo_10.26061.10051.0_x64__8wekyb3d8bbwe | 10.26061.10051.0 |
| Mozilla Maintenance Service | ARP\Machine\X64\MozillaMaintenanceService | 1.19.9b |
| MPEG-2 Video Extension | MSIX\Microsoft.MPEG2VideoExtension_1.2.32.0_x64__8wekyb3d8bbwe | 1.2.32.0 |
| MSN Weather | MSIX\Microsoft.BingWeather_4.54.63045.0_x64__8wekyb3d8bbwe | 4.54.63045.0 |
| My Dell | MSIX\DellInc.MyDell_2.2.6.0_x64__htrsf667h5kn2 | 2.2.6.0 |
| MySQL Connector C++ 8.0 | ARP\Machine\X64\{1671CCF3-0C70-4C71-BBA2-83408AB325B5} | 8.0.31 |
| MySQL Connector J | ARP\Machine\X86\{F2BAAC7E-935C-4A0E-8689-4AF4E0A0A962} | 8.0.31 |
| MySQL Connector NET 8.0.31 | ARP\Machine\X86\{C68480ED-BE15-4F0F-9E94-35DF7A0CD29F} | 8.0.31 |
| MySQL Connector Python v8.0.31 | ARP\Machine\X64\{D46BFD4D-FC6F-4F53-96C8-50C3E9C79CD2} | 8.0.31 |
| MySQL Connector/ODBC 8.0 | ARP\Machine\X64\{74861C33-82F5-4A05-A62F-0DE127F5FCDC} | 8.0.31 |
| MySQL Documents 5.7 | ARP\Machine\X86\{39BCFA0E-BB82-4129-95EF-C864C3941698} | 5.7.40 |
| MySQL Examples and Samples 5.7 | ARP\Machine\X86\{EBC90799-5FE8-4F9B-80BA-E8024F4A0A2A} | 5.7.40 |
| MySQL Installer - Community | Oracle.MySQL | 1.6.4.0 |
| MySQL Installer for Windows - Community | Oracle.MySQL | 1.6.5.0 |
| MySQL Router 8.0 | ARP\Machine\X64\{242B85D2-9F98-49DD-9B29-80A5E3855C3D} | 8.0.31 |
| MySQL Server 5.7 | Oracle.MySQL | 5.7.40 |
| MySQL Shell 8.0.31 | Oracle.MySQLShell | 8.0.31 |
| MySQL Workbench 8.0 CE | Oracle.MySQLWorkbench | 8.0.31 |
| Nani Translate | MSIX\KiokuLLC.NaniTranslate_1.1.13.0_x64__mpzwtaxj5jyfc | 1.1.13.0 |
| Narrator Extension - Excel | MSIX\MicrosoftWindows.NarratorScript.Excel_1.0.14.0_neutral__cw5n1h2txyewy | 1.0.14.0 |
| Narrator Extension - Word | MSIX\MicrosoftWindows.NarratorExtension-Word_2.0.3.0_neutral__cw5n1h2txyewy | 2.0.3.0 |
| NarratorExtension - Outlook | MSIX\MicrosoftWindows.NarratorScript.Outlook_2.0.4.0_neutral__cw5n1h2txyewy | 2.0.4.0 |
| News | MSIX\Microsoft.BingNews_4.56.21872.0_x64__8wekyb3d8bbwe | 4.56.21872.0 |
| ngrok | 9MVS1J51GMK6 | 3.39.9.0 |
| OBS Studio | OBSProject.OBSStudio | 32.1.1 |
| OfficePushNotificationsUtility | MSIX\Microsoft.OfficePushNotificationUtility_16.0.20430.20146_neutral__8wekyb3d8bbwe | 16.0.20430.20146 |
| OneDrive | MSIX\Microsoft.OneDriveSync_26178.913.7.0_neutral__8wekyb3d8bbwe | 26178.913.7.0 |
| OneNote Virtual Printer | MSIX\Microsoft.Office.OneNoteVirtualPrinter_1.0.0.0_x64__8wekyb3d8bbwe | 1.0.0.0 |
| OpenSSL Light 4.0.3 (64-bit) | ShiningLight.OpenSSL.Light | 4.0.3 |
| Outlook for Windows | Microsoft.Outlook | 1.2026.915.300 |
| Paint | MSIX\Microsoft.Paint_11.2605.81.0_x64__8wekyb3d8bbwe | 11.2605.81.0 |
| PDFelement Shell Extension | MSIX\PDFelement.ShellExtension_1.0.0.0_x64__xepv84zttm8m2 | 1.0.0.0 |
| Phone Link | MSIX\Microsoft.YourPhone_1.26072.257.0_x64__8wekyb3d8bbwe | 1.26072.257.0 |
| Podman | RedHat.Podman | 5.5.0 |
| Power Automate | MSIX\Microsoft.PowerAutomateDesktop_1.0.2141.0_x64__8wekyb3d8bbwe | 1.0.2141.0 |
| PowerShell | Microsoft.PowerShell | 7.6.6.0 |
| PowerShell 7.6.6.0-x64 | Microsoft.PowerShell | 7.6.6.0 |
| PowerToys (Preview) x64 | XP89DCGQ3K6VLD | 0.100.2 |
| PowerToys FileLocksmith Context Menu | MSIX\Microsoft.PowerToys.FileLocksmithContextMenu_0.100.2.0_neutral__8wekyb3d8bbwe | 0.100.2.0 |
| PowerToys ImageResizer Context Menu | MSIX\Microsoft.PowerToys.ImageResizerContextMenu_0.100.2.0_neutral__8wekyb3d8bbwe | 0.100.2.0 |
| PowerToys PowerRename Context Menu | MSIX\Microsoft.PowerToys.PowerRenameContextMenu_0.100.2.0_neutral__8wekyb3d8bbwe | 0.100.2.0 |
| PowerToys.SparseApp | MSIX\Microsoft.PowerToys.SparseApp_0.100.2.0_neutral__8wekyb3d8bbwe | 0.100.2.0 |
| Processing | ProcessingFoundation.Processing | 4.4.1 |
| Pulse Application Launcher | ARP\Machine\X86\{A419D094-5F85-49A1-A9F1-AB3A366DC09C} | 9.1.10247 |
| Pulse Secure Setup Client | ARP\User\X64\Pulse_Setup_Client | 9.1.12.10247 |
| Pulse Secure Setup Client 64-bit Activex Control | ARP\Machine\X64\Pulse_Setup_Client Activex Control | 3.1.1.1 |
| Pulse Secure Setup Client Activex Control | ARP\Machine\X86\Pulse_Setup_Client Activex Control | 3.1.1.1 |
| Quick Assist | MSIX\MicrosoftCorporationII.QuickAssist_2.0.61.0_x64__8wekyb3d8bbwe | 2.0.61.0 |
| Raw Image Extension | MSIX\Microsoft.RawImageExtension_2.5.35.0_x64__8wekyb3d8bbwe | 2.5.35.0 |
| Realtek Audio Driver | ARP\Machine\X86\{F132AF7F-7BCA-4EDE-8A7C-958108FE7DBC} | 6.0.9780.1 |
| Rustup: the Rust toolchain installer | Rustlang.Rustup | 1.28.2 |
| Safe Exam Browser | ETHZurich.SafeExamBrowser | 3.10.0 |
| Slack | SlackTechnologies.Slack | 4.51.185 |
| Slack | SlackTechnologies.Slack | 4.51.185.0 |
| SmartByte Drivers and Services | ARP\Machine\X64\{19A754FE-0343-4311-835F-33EAB7ADEA7B} | 3.1122.728.7 |
| Snipping Tool | MSIX\Microsoft.ScreenSketch_11.2608.41.0_x64__8wekyb3d8bbwe | 11.2608.41.0 |
| Solitaire & Casual Games | MSIX\Microsoft.MicrosoftSolitaireCollection_4.27.9181.0_x64__8wekyb3d8bbwe | 4.27.9181.0 |
| Speech Pack - English (United States) | MSIX\MicrosoftWindows.Speech.en-US.1_1.0.28.0_x64__cw5n1h2txyewy | 1.0.28.0 |
| Speech Pack - Japanese (Japan) | MSIX\MicrosoftWindows.Speech.ja-JP.1_1.0.21.0_x64__cw5n1h2txyewy | 1.0.21.0 |
| Start Experiences App | MSIX\Microsoft.StartExperiencesApp_1.380.2.0_x64__8wekyb3d8bbwe | 1.380.2.0 |
| Store Experience Host | MSIX\Microsoft.StorePurchaseApp_22608.1401.1.0_x64__8wekyb3d8bbwe | 22608.1401.1.0 |
| Teams Machine-Wide Installer | Microsoft.Teams.Classic | 1.4.0.19572 |
| ThunderboltTM Control Center | MSIX\AppUp.ThunderboltControlCenter_1.0.37.0_x64__8j3eq9eme6ctt | 1.0.37.0 |
| Ubuntu | Canonical.Ubuntu | 2604.1.75.0 |
| Visual Studio Code | MSIX\Microsoft.VisualStudioCode_1.0.125.0_neutral__8wekyb3d8bbwe | 1.0.125.0 |
| Visual Studio Code - Insiders | MSIX\Microsoft.VisualStudioCodeInsiders_1.0.107.0_neutral__8wekyb3d8bbwe | 1.0.107.0 |
| VP9 Video Extensions | MSIX\Microsoft.VP9VideoExtensions_1.2.20.0_x64__8wekyb3d8bbwe | 1.2.20.0 |
| Vrew 3.6.1 | VoyagerX.Vrew | 3.6.1 |
| vs_CoreEditorFonts | ARP\Machine\X86\{1851460E-0E63-4117-B5BA-25A2F045801B} | 17.7.40001 |
| Waves MaxxAudio Pro for Dell 2021 | MSIX\WavesAudio.MaxxAudioProforDell2021_4.0.53.0_x64__fh4rh281wavaa | 4.0.53.0 |
| Web Media Extensions | MSIX\Microsoft.WebMediaExtensions_2.1.51.0_x64__8wekyb3d8bbwe | 2.1.51.0 |
| WebP Image Extension | MSIX\Microsoft.WebpImageExtension_1.2.31.0_x64__8wekyb3d8bbwe | 1.2.31.0 |
| Weka 3.8.6 | UniversityOfWaikato.Weka | 3.8.6 |
| Widgets Platform Runtime | MSIX\Microsoft.WidgetsPlatformRuntime_1.6.19.0_x64__8wekyb3d8bbwe | 1.6.19.0 |
| WinAppRuntime.Singleton | MSIX\MicrosoftCorporationII.WinAppRuntime.Singleton_8002.5.1.0_x64__8wekyb3d8bbwe | 8002.5.1.0 |
| Windows Advanced Settings | MSIX\Microsoft.Windows.DevHome_0.2100.858.0_x64__8wekyb3d8bbwe | 0.2100.858.0 |
| Windows Application Compatibility Enhancements | MSIX\Microsoft.ApplicationCompatibilityEnhancements_1.2511.9.0_x64__8wekyb3d8bbwe | 1.2511.9.0 |
| Windows Calculator | MSIX\Microsoft.WindowsCalculator_11.2607.0.0_x64__8wekyb3d8bbwe | 11.2607.0.0 |
| Windows Camera | MSIX\Microsoft.WindowsCamera_2026.2607.1.0_x64__8wekyb3d8bbwe | 2026.2607.1.0 |
| Windows Clock | MSIX\Microsoft.WindowsAlarms_11.2607.6.0_x64__8wekyb3d8bbwe | 11.2607.6.0 |
| Windows Maps | MSIX\Microsoft.WindowsMaps_11.2506.3.0_x64__8wekyb3d8bbwe | 11.2506.3.0 |
| Windows Media Player | MSIX\Microsoft.ZuneMusic_11.2607.16.0_x64__8wekyb3d8bbwe | 11.2607.16.0 |
| Windows Notepad | MSIX\Microsoft.WindowsNotepad_11.2607.14.0_x64__8wekyb3d8bbwe | 11.2607.14.0 |
| Windows Package Manager Source (winget) V2 | MSIX\Microsoft.Winget.Source_2026.1015.525.46_neutral__8wekyb3d8bbwe | 2026.1015.525.46 |
| Windows Package Manager Source (winget-font) V2 | MSIX\Microsoft.Winget.Fonts.Source_2025.1016.311.49_neutral__8wekyb3d8bbwe | 2025.1016.311.49 |
| Windows Security | MSIX\Microsoft.SecHealthUI_1000.29628.1000.0_x64__8wekyb3d8bbwe | 1000.29628.1000.0 |
| Windows Sound Recorder | MSIX\Microsoft.WindowsSoundRecorder_11.2607.1.0_x64__8wekyb3d8bbwe | 11.2607.1.0 |
| Windows Subsystem for Linux | Microsoft.WSL | 2.7.14.0 |
| Windows Terminal | Microsoft.WindowsTerminal | 1.24.12741.0 |
| Windows Web Experience Pack | MSIX\MicrosoftWindows.Client.WebExperience_526.21100.40.0_x64__cw5n1h2txyewy | 526.21100.40.0 |
| WindowsAppRuntime.1.1 | Microsoft.WindowsAppRuntime.1.1 | 1.1.5 |
| WindowsAppRuntime.1.1 | Microsoft.WindowsAppRuntime.1.1 | 1.1.5 |
| WindowsAppRuntime.1.2 | Microsoft.WindowsAppRuntime.1.2 | 1.2.5 |
| WindowsAppRuntime.1.2 | Microsoft.WindowsAppRuntime.1.2 | 1.2.5 |
| WindowsAppRuntime.1.3 | Microsoft.WindowsAppRuntime.1.3 | 1.3.3 |
| WindowsAppRuntime.1.3 | Microsoft.WindowsAppRuntime.1.3 | 1.3.3 |
| WindowsAppRuntime.1.4 | Microsoft.WindowsAppRuntime.1.4 | 1.4.7 |
| WindowsAppRuntime.1.4 | Microsoft.WindowsAppRuntime.1.4 | 1.4.7 |
| WindowsAppRuntime.1.5 | Microsoft.WindowsAppRuntime.1.5 | 1.5.9 |
| WindowsAppRuntime.1.5 | Microsoft.WindowsAppRuntime.1.5 | 1.5.9 |
| WindowsAppRuntime.1.6 | Microsoft.WindowsAppRuntime.1.6 | 1.6.9 |
| WindowsAppRuntime.1.6 | Microsoft.WindowsAppRuntime.1.6 | 1.6.9 |
| WindowsAppRuntime.1.7 | Microsoft.WindowsAppRuntime.1.7 | 1.7.9 |
| WindowsAppRuntime.1.7 | Microsoft.WindowsAppRuntime.1.7 | 1.7.9 |
| WindowsAppRuntime.1.8 | Microsoft.WindowsAppRuntime.1.8 | > 1.8.10 |
| WindowsAppRuntime.1.8 | Microsoft.WindowsAppRuntime.1.8 | > 1.8.10 |
| WindowsAppRuntime.2 | Microsoft.WindowsAppRuntime.2 | 2.5.1.0 |
| WindowsAppRuntime.2 | Microsoft.WindowsAppRuntime.2 | 2.5.1.0 |
| WindowsAppRuntime.2 | Microsoft.WindowsAppRuntime.2 | 2.4.0.0 |
| WinSCP 6.1.2 | ARP\Machine\X86\winscp3_is1 | 6.1.2 |
| XBOX | MSIX\Microsoft.GamingApp_2609.1001.16.0_x64__8wekyb3d8bbwe | 2609.1001.16.0 |
| Xbox Game Bar Plugin | MSIX\Microsoft.XboxGameOverlay_1.54.4001.0_x64__8wekyb3d8bbwe | 1.54.4001.0 |
| Xbox Identity Provider | MSIX\Microsoft.XboxIdentityProvider_12.130.16001.0_x64__8wekyb3d8bbwe | 12.130.16001.0 |
| Xbox TCUI | MSIX\Microsoft.Xbox.TCUI_1.24.10001.0_x64__8wekyb3d8bbwe | 1.24.10001.0 |
| YouTube | ARP\User\X64\b143d8d0c0c204e4edb5efdec3a851c0 | 1.0 |
| YouTube Music | ARP\User\X64\e4085dfc8d806e425ce4ec84c17039fe | 1.0 |
| Zed | ZedIndustries.Zed | 1.22.0 |
| Zed | MSIX\ZedIndustries.Zed_1.0.0.0_neutral__japxn1gcva8rg | 1.0.0.0 |
| Zen Browser (x64 en-US) | Zen-Team.Zen-Browser | 1.23.2b |
| Zoom Workplace | Zoom.Zoom.EXE | 7.1.9 (48550) |
| スプレッドシート | ARP\User\X64\5477c45c970159b3b392765b3f0e95de | 1.0 |
| スライド | ARP\User\X64\e473876603dd7d577507802864cef404 | 1.0 |
| ドキュメント | ARP\User\X64\01c9fbfc645dfe25e4b438766453abc4 | 1.0 |
| 情報分析と可視化 5/29 提出課題 | ARP\User\X64\ed9d9a006972699bfbbbe78cd2035be2 | 1.0 |
| 日本語 ローカル エクスペリエンス パック | MSIX\Microsoft.LanguageExperiencePackja-JP_26100.174.273.0_neutral__8wekyb3d8bbwe | 26100.174.273.0 |
| 秀丸エディタ (9.19) | ARP\Machine\X86\Hidemaru | 9.19 |

### 2.3 Chocolatey（16）

```
Chocolatey v2.4.3
chocolatey 2.4.3
chocolatey-compatibility.extension 1.0.0
chocolatey-core.extension 1.4.0
chocolatey-windowsupdate.extension 1.0.5
cloudflared 2025.8.1
KB2919355 1.0.20160915
KB2919442 1.0.20160915
KB2999226 1.0.20181019
KB3033929 1.0.5
KB3035131 1.0.3
make 4.4.1
maven 3.9.11
mkcert 1.4.4
ngrok 3.22.1
OpenSSL.Light 3.1.4
vcredist140 14.44.35211
16 packages installed.
```

### 2.4 npm -g（24）

```
C:\Users\%USERNAME%\AppData\Roaming\npm
+-- @aikidosec/safe-chain@1.1.10
+-- @devcontainers/cli@0.76.0
+-- @executeautomation/playwright-mcp-server@1.0.3
+-- @github/copilot@0.0.372
+-- @google/clasp@2.4.2
+-- @google/gemini-cli@0.15.1
+-- @google/jules@
+-- @inkdropapp/ipm-cli@1.3.1
+-- @inkdropapp/mcp-server@1.1.1
+-- @line/liff-cli@0.4.1
+-- @openai/codex@0.162.1
+-- @opencode/cli@2.0.27
+-- @typescript/native-preview@7.0.0-dev.20250816.1
+-- codex@
+-- dev3000@0.0.59
+-- netlify-cli@22.1.3
+-- notion@0.1.0 -> .\..\..\..\..\..\WINDOWS\system32\mcp-notion-server\notion
+-- npm@11.13.0
+-- pnpm@10.17.1
+-- task-master-ai@0.31.1
+-- typescript@5.7.3
`-- vercel@45.0.9
```

### 2.5 pnpm global（直接導入）

- .pnpm
- pnpm

### 2.6 pip — グローバル（Python 3.13, 134）

```
aiohappyeyeballs==2.6.1
aiohttp==3.13.3
aiosignal==1.4.0
alembic==1.18.3
antlr4-python3-runtime==4.9.3
anyio==4.12.0
asteroid-filterbanks==0.4.0
attrs==25.4.0
av==16.1.0
build==1.3.0
CacheControl==0.14.4
certifi==2025.11.12
cffi==2.0.0
charset-normalizer==3.4.4
cleo==2.1.0
click==8.3.1
colorama==0.4.6
colorlog==6.10.1
contourpy==1.3.3
crashtest==0.4.1
ctranslate2==4.7.1
cycler==0.12.1
distlib==0.4.0
docopt==0.6.2
dulwich==0.24.10
einops==0.8.2
faster-whisper==1.2.1
fastjsonschema==2.21.2
filelock==3.20.1
findpython==0.7.1
flatbuffers==25.12.19
fonttools==4.61.1
frozenlist==1.8.0
fsspec==2026.2.0
greenlet==3.3.1
h11==0.16.0
httpcore==1.0.9
httpx==0.28.1
huggingface_hub==0.36.2
HyperPyYAML==1.2.3
idna==3.11
installer==0.7.0
jaraco.classes==3.4.0
jaraco.context==6.0.2
jaraco.functools==4.4.0
Jinja2==3.1.6
joblib==1.5.3
julius==0.2.7
keyring==25.7.0
kiwisolver==1.4.9
lightning==2.6.1
lightning-utilities==0.15.2
Mako==1.3.10
markdown-it-py==4.0.0
MarkupSafe==3.0.3
matplotlib==3.10.8
mdurl==0.1.2
more-itertools==10.8.0
mpmath==1.3.0
msgpack==1.1.2
multidict==6.7.1
networkx==3.6.1
nltk==3.9.2
numpy==2.4.2
omegaconf==2.3.0
onnxruntime==1.24.1
optuna==4.7.0
packaging==25.0
pandas==3.0.0
pbs-installer==2025.12.17
pillow==12.1.0
pip==26.0.1
pkginfo==1.12.1.2
platformdirs==4.5.1
poetry==2.2.1
poetry-core==2.2.1
primePy==1.3
propcache==0.4.1
protobuf==6.33.5
pyannote.audio==3.4.0
pyannote.core==5.0.0
pyannote.database==5.1.3
pyannote.metrics==3.2.1
pyannote.pipeline==3.0.1
pycparser==3.0
Pygments==2.19.2
pyparsing==3.3.2
pyproject_hooks==1.2.0
python-dateutil==2.9.0.post0
pytorch-lightning==2.6.1
pytorch-metric-learning==2.9.0
pywin32-ctypes==0.2.3
PyYAML==6.0.3
RapidFuzz==3.14.3
regex==2026.1.15
requests==2.32.5
requests-toolbelt==1.0.0
rich==14.3.2
ruamel.yaml==0.18.17
ruamel.yaml.clib==0.2.15
safetensors==0.7.0
scikit-learn==1.8.0
scipy==1.17.0
semver==3.0.4
sentencepiece==0.2.1
setuptools==81.0.0
shellingham==1.5.4
six==1.17.0
sortedcontainers==2.4.0
soundfile==0.13.1
speechbrain==1.0.3
SQLAlchemy==2.0.46
sympy==1.14.0
tabulate==0.9.0
tensorboardX==2.6.4
threadpoolctl==3.6.0
tokenizers==0.22.2
tomlkit==0.13.3
torch==2.8.0
torch-audiomentations==0.12.0
torch_pitch_shift==1.2.5
torchaudio==2.8.0
torchmetrics==1.8.2
tqdm==4.67.3
transformers==4.57.6
trove-classifiers==2025.12.1.14
typer==0.21.1
typing_extensions==4.15.0
tzdata==2025.3
urllib3==2.6.2
virtualenv==20.35.4
whisperx==3.7.6
yarl==1.22.0
zstandard==0.25.0
```

### 2.7 pip — ユーザー site（`%APPDATA%\Python`）

```
Package            Version
------------------ ------------
anyio              4.12.0
build              1.3.0
CacheControl       0.14.4
certifi            2025.11.12
charset-normalizer 3.4.4
cleo               2.1.0
colorama           0.4.6
crashtest          0.4.1
distlib            0.4.0
dulwich            0.24.10
fastjsonschema     2.21.2
filelock           3.20.1
findpython         0.7.1
h11                0.16.0
httpcore           1.0.9
httpx              0.28.1
idna               3.11
installer          0.7.0
jaraco.classes     3.4.0
jaraco.context     6.0.2
jaraco.functools   4.4.0
keyring            25.7.0
more-itertools     10.8.0
msgpack            1.1.2
packaging          25.0
pbs-installer      2025.12.17
pkginfo            1.12.1.2
platformdirs       4.5.1
poetry             2.2.1
poetry-core        2.2.1
pyproject_hooks    1.2.0
pywin32-ctypes     0.2.3
RapidFuzz          3.14.3
requests           2.32.5
requests-toolbelt  1.0.0
shellingham        1.5.4
tomlkit            0.13.3
trove-classifiers  2025.12.1.14
urllib3            2.6.2
virtualenv         20.35.4
zstandard          0.25.0
```

### 2.8 Rust — `~/.cargo/bin`

- cargo-clippy.exe
- cargo-fmt.exe
- cargo-miri.exe
- cargo.exe
- clippy-driver.exe
- rls.exe
- rust-analyzer.exe
- rust-gdb.exe
- rust-gdbgui.exe
- rust-lldb.exe
- rustc.exe
- rustdoc.exe
- rustfmt.exe
- rustup.exe

### 2.9 uv — `~/.local/bin`


### 2.10 Go — `~/go/bin`

- gopls.exe

### 2.11 nvm-windows（Node）

```
    24.13.0
  * 22.22.0 (Currently using 64-bit executable)
    18.20.4
```

### 2.12 dotnet

**SDK 無し** → グローバルツール無し（`dotnet tool` 不可）。

### 2.13 PowerShell Gallery モジュール（既定 + 追加）

- `GoogleCloud`
- `GoogleCloudBeta`
- （他は PowerShell 同梱モジュール）

### 2.14 未導入の確認済みマネージャ

- scoop / cargo(第三者) / go toolchain / gem(ruby) / composer / conda / pipx / bun / yarn / deno / volta / asdf / fnm / pixi — **いずれも無し**

## 3. 言語ランタイム/スタック

- **Node**: nvm-windows（18.20.4 / 22.22.0* / 24.13.0）＋ mise node@24.16.0（二重）→ 目標 mise `26.x`
- **Python**: 下記 §3.1 → 目標 mise `3.14.x`
- **Rust**: stable-msvc
- **PHP**: MAMP 7.4.16
- **Java**: Amazon Corretto JDK17
- **.NET**: runtime のみ（SDK 無し）
- **Go**: 無し
- **Docker**: Docker Desktop ＋ Sandboxes（`sbx, sbx-gui, llmman`）

### 3.1 Python の全実体（削除計画）

| 実体 | 版 | サイズ | 状態 |
|---|---|---|---|
| `Programs\Python310` | (python.exe 欠落) | 45 MB | **🗑 削除済 2026-10-15**（PATH 2 件も除去） |
| `Programs\Python313` | 3.13.11 | 2,272 MB | ⚠️ **134 pip** を内包 → uv 移行後に削除 |
| mise python | 3.13.13 | 60 MB | → 目標 `3.14.x` |
| `~/.pyenv`（pyenv-win + 3.10.0/3.11.0/3.12.2） | — | 452 MB | **🗑 削除済 2026-10-15**（プロジェクトは退避） |
| `%APPDATA%\Python\Python313` | — | — | pip **ユーザー site**（§2.7） |

**~/.pyenv に同居していたプロジェクト**（削除時に `backup-pyenv-2026-10-15/` へ退避）:

| プロジェクト | 要求 Python |
|---|---|
| `edinet` | `^3.11` |
| `ai-bot/line-bot-local` | 3.11.0 |
| `ai-bot/line-bot-local/claude` | 3.11.0 |
| `ai-bot/line-bot-local/python-gcp-linebot` | 3.10.0 |

## 4. アプリ（Program Files / LocalAppData）

### 4.1 `C:\Program Files`

```
Adobe
Apidog
Canon
Common Files
curl
Dell
Docker
dotnet
en-US
Fortinet
Git
Google
HeidiSQL
Intel
Internet Explorer
ja-JP
Logi
LogiDownloadAssistant
LogiOptionsPlus
MATLAB
Maxon Cinema 4D 2024
Meltype
Microsoft
Microsoft Office
Microsoft Office 15
Microsoft OneDrive
Microsoft Update Health Tools
Microsoft Visual Studio
ModifiableWindowsApps
MSBuild
MySQL
nodejs
obs-studio
OpenSSL-Win64
PowerToys
Razer
RedHat
Reference Assemblies
Rivet Networks
SafeExamBrowser
Waves
Weka-3-8-6
Windows Defender
Windows Mail
Windows Media Player
Windows NT
Windows Photo Viewer
WindowsPowerShell
WSL
Zen Browser
```

### 4.2 `C:\Program Files (x86)`

```
BUFFALO
Canon
cloudflared
Common Files
Dell
Dell Digital Delivery Services
dotnet
DummyDir
Freemake
Google
Hidemaru
Intel
Internet Explorer
KWIC Concordance
Microsoft
Microsoft Visual Studio
Microsoft.NET
Mozilla Maintenance Service
MSBuild
MySQL
Nitro PDF
Pulse Secure
Razer
Realtek
Reference Assemblies
Teams Installer
Windows Defender
Windows Mail
Windows Media Player
Windows NT
Windows Photo Viewer
WindowsPowerShell
WinSCP
Wondershare
```

### 4.3 `%LOCALAPPDATA%\Programs`

```
Canva
Common
cursor
Delta
Meltype
Microsoft VS Code
Microsoft VS Code Insiders
vrew
Zed
```

## 5. Store / UWP（Appx）

件数: **200**。全名（`Get-AppxPackage`）:

```
1527c705-839a-4832-9118-54d4Bd6a0c89
34791E63.CanonInkjetPrintUtility
aimgr
AppUp.IntelArcSoftware
AppUp.IntelGraphicsExperience
AppUp.IntelOptaneMemoryandStorageManagement
AppUp.ThunderboltControlCenter
c5e2524a-ea46-4f67-841f-6a9465d9d515
CanonicalGroupLimited.Ubuntu
Clipchamp.Clipchamp
com.tinyspeck.slackdesktop
DellInc.DellCustomerConnect
DellInc.DellDigitalDelivery
DellInc.DellSupportAssistforPCs
DellInc.DellUpdate
DellInc.MyDell
E2A4F912-2574-4A75-9BB0-0D023378592B
F.luxSoftwareLLC.f.lux
F46D4000-FD22-4DB4-AC8E-4E1DDDE828FE
KiokuLLC.NaniTranslate
LINE
Microsoft.AAD.BrokerPlugin
Microsoft.AccountsControl
Microsoft.AIFabric.CBS.1.6
Microsoft.ApplicationCompatibilityEnhancements
Microsoft.AsyncTextService
Microsoft.AV1VideoExtension
Microsoft.AVCEncoderVideoExtension
Microsoft.BingNews
Microsoft.BingSearch
Microsoft.BingWeather
Microsoft.BioEnrollment
Microsoft.CommandPalette
Microsoft.CredDialogHost
Microsoft.DesktopAppInstaller
Microsoft.ECApp
Microsoft.Edge.GameAssist
Microsoft.GamingApp
Microsoft.GetHelp
Microsoft.HEIFImageExtension
Microsoft.HEVCVideoExtension
Microsoft.Ink.Handwriting.ja-JP.1.0
Microsoft.Ink.Handwriting.Main.ja-JP.1.0
Microsoft.LanguageExperiencePacken-US
Microsoft.LanguageExperiencePackja-JP
Microsoft.LockApp
Microsoft.M365Companions
Microsoft.MicrosoftEdge.Stable
Microsoft.MicrosoftEdgeDevToolsClient
Microsoft.MicrosoftSolitaireCollection
Microsoft.MicrosoftStickyNotes
Microsoft.MPEG2VideoExtension
Microsoft.NET.Native.Framework.1.2
Microsoft.NET.Native.Framework.2.1
Microsoft.NET.Native.Framework.2.2
Microsoft.NET.Native.Runtime.1.1
Microsoft.NET.Native.Runtime.2.1
Microsoft.NET.Native.Runtime.2.2
Microsoft.Office.ActionsServer
Microsoft.Office.OneNoteVirtualPrinter
Microsoft.OfficePushNotificationUtility
Microsoft.OneDriveSync
Microsoft.OutlookForWindows
Microsoft.Paint
Microsoft.People
Microsoft.PowerAutomateDesktop
Microsoft.PowerShell
Microsoft.PowerToys.FileLocksmithContextMenu
Microsoft.PowerToys.ImageResizerContextMenu
Microsoft.PowerToys.PowerRenameContextMenu
Microsoft.PowerToys.SparseApp
Microsoft.RawImageExtension
Microsoft.ScreenSketch
Microsoft.SecHealthUI
Microsoft.Services.Store.Engagement
Microsoft.StartExperiencesApp
Microsoft.StorePurchaseApp
Microsoft.Todos
Microsoft.UI.Xaml.2.3
Microsoft.UI.Xaml.2.4
Microsoft.UI.Xaml.2.7
Microsoft.UI.Xaml.2.8
Microsoft.UI.Xaml.CBS
Microsoft.VCLibs.110.00
Microsoft.VCLibs.140.00
Microsoft.VCLibs.140.00.UWPDesktop
Microsoft.VisualStudioCode
Microsoft.VisualStudioCodeInsiders
Microsoft.VP9VideoExtensions
Microsoft.WebMediaExtensions
Microsoft.WebpImageExtension
Microsoft.WidgetsPlatformRuntime
Microsoft.Win32WebViewHost
Microsoft.Windows.Apprep.ChxApp
Microsoft.Windows.AugLoop.CBS
Microsoft.Windows.CapturePicker
Microsoft.Windows.CloudExperienceHost
Microsoft.Windows.ContentDeliveryManager
Microsoft.Windows.DevHome
Microsoft.Windows.NarratorQuickStart
Microsoft.Windows.OOBENetworkCaptivePortal
Microsoft.Windows.OOBENetworkConnectionFlow
Microsoft.Windows.ParentalControls
Microsoft.Windows.PeopleExperienceHost
Microsoft.Windows.Photos
Microsoft.Windows.PinningConfirmationDialog
Microsoft.Windows.PrintQueueActionCenter
Microsoft.Windows.ShellExperienceHost
Microsoft.Windows.StartMenuExperienceHost
Microsoft.Windows.XGpuEjectDialog
Microsoft.WindowsAlarms
Microsoft.WindowsAppRuntime.1.1
Microsoft.WindowsAppRuntime.1.2
Microsoft.WindowsAppRuntime.1.3
Microsoft.WindowsAppRuntime.1.4
Microsoft.WindowsAppRuntime.1.5
Microsoft.WindowsAppRuntime.1.6
Microsoft.WindowsAppRuntime.1.7
Microsoft.WindowsAppRuntime.1.8
Microsoft.WindowsAppRuntime.2
Microsoft.WindowsAppRuntime.CBS.1.6
Microsoft.WindowsAppRuntime.CBS.2
Microsoft.WindowsCalculator
Microsoft.WindowsCamera
microsoft.windowscommunicationsapps
Microsoft.WindowsFeedbackHub
Microsoft.WindowsMaps
Microsoft.WindowsNotepad
Microsoft.WindowsSoundRecorder
Microsoft.WindowsStore
Microsoft.WindowsTerminal
Microsoft.Winget.Fonts.Source
Microsoft.Winget.Source
Microsoft.Xbox.TCUI
Microsoft.XboxGameCallableUI
Microsoft.XboxGameOverlay
Microsoft.XboxGamingOverlay
Microsoft.XboxIdentityProvider
Microsoft.XboxSpeechToTextOverlay
Microsoft.YourPhone
Microsoft.ZuneMusic
Microsoft.ZuneVideo
MicrosoftCorporationII.MicrosoftFamily
MicrosoftCorporationII.QuickAssist
MicrosoftCorporationII.WinAppRuntime.Main.1.5
MicrosoftCorporationII.WinAppRuntime.Main.1.8
MicrosoftCorporationII.WinAppRuntime.Singleton
MicrosoftCorporationII.WindowsSubsystemForLinux
MicrosoftWindows.61869720.Voiess
MicrosoftWindows.61869721.Livtop
MicrosoftWindows.61869722.Speion
MicrosoftWindows.61869836.InpApp
MicrosoftWindows.Client.CBS
MicrosoftWindows.Client.Core
MicrosoftWindows.Client.CoreAI
MicrosoftWindows.Client.FileExp
MicrosoftWindows.Client.OOBE
MicrosoftWindows.Client.Photon
MicrosoftWindows.Client.WebExperience
MicrosoftWindows.CrossDevice
MicrosoftWindows.NarratorExtension-Word
MicrosoftWindows.NarratorScript.Excel
MicrosoftWindows.NarratorScript.Outlook
MicrosoftWindows.Speech.en-US.1
MicrosoftWindows.Speech.ja-JP.1
MicrosoftWindows.UndockedDevKit
MicrosoftWindows.Voice.en-US.Jenny.1
MSTeams
ngrok.ngrok
OpenAI.Codex
PDFelement.ShellExtension
PortraitDisplays.DellCinemaColor
ScreenovateTechnologies.DellMobileConnectPlus
WavesAudio.MaxxAudioProforDell2021
Windows.CBSPreview
windows.immersivecontrolpanel
Windows.PrintDialog
ZedIndustries.Zed
```

## 6. PATH 上の手置き / アプリ同梱

- C:\Users\%USERNAME%\AppData\Local\pnpm\bin
- C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python313\Scripts\
- C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python313\
- C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python310\Scripts\
- C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python310\
- C:\Program Files\Amazon Corretto\jdk17.0.16_8\bin
- C:\Users\%USERNAME%\AppData\Local\Programs\Microsoft VS Code\bin
- %USERPROFILE%\AppData\Local\Programs\cursor\resources\app\bin
- %USERPROFILE%\AppData\Roaming\Code\User\globalStorage\ms-vscode-remote.remote-containers\cli-bin
- C:\WINDOWS\System32\WindowsPowerShell\v1.0\
- C:\Program Files (x86)\Common Files\Intel\Shared Libraries\redist\intel64\compiler
- C:\WINDOWS\system32
- C:\WINDOWS
- C:\WINDOWS\System32\Wbem
- C:\WINDOWS\System32\OpenSSH\
- C:\Program Files\dotnet\
- C:\WINDOWS\System32\WindowsPowerShell\v1.0\
- C:\Program Files (x86)\dotnet\
- C:\Program Files\Git\cmd
- C:\Program Files\MySQL\MySQL Shell 8.0\bin\
- C:\Users\%USERNAME%\AppData\Local\Microsoft\WindowsApps
- C:\Users\%USERNAME%\AppData\Roaming\npm
- node_mod
- C:\Users\%USERNAME%\AppData\Local\Programs\Zed\bin
- C:\Users\%USERNAME%\AppData\Local\Programs\Delta\bin
- C:\Users\%USERNAME%\AppData\Local\DockerSandboxes\bin\
- C:\Users\%USERNAME%\AppData\Local\Microsoft\WinGet\Packages\Betterleaks.Betterleaks_Microsoft.Winget.Source_8wekyb3d8bbwe
- C:\Users\%USERNAME%\AppData\Local\Microsoft\WinGet\Packages\evilmartians.lefthook_Microsoft.Winget.Source_8wekyb3d8bbwe

（PATH 上の exe スキャン詳細は `inventory-path-exes.txt`）

## 7. スコープ外（確定）

- **WSL（Ubuntu）— 無視**。Ubuntu 内部に直接導入されたものは**不可侵**（変更・削除しない）。Windows 側の **WSL マウント/成果物のみ**整理可。
- エディタ拡張（VS Code / Cursor / Zed）
- ブラウザ拡張（Chrome / Dev / Zen / Slack）
- UWP/Store アプリの一部（winget 側で扱う）

## 8. 移行先の分類

| 種別 | 例 | 移行先 |
|---|---|---|
| mise registry あり | node, python, uv, gh, jq, rg, fd, **hk**(旧 lefthook), doppler, mo, waza, rtk, betterleaks | **mise**（正確ピン + lock） |
| Python CLI | apm, skillspector, 既存 pip 群 | **mise `pypi:`**（Takumi Guard 済） |
| npm 由来 | safe-chain, codex, gemini-cli, copilot, MCP 群, vercel, netlify… | **Takumi Guard npm**（or mise `npm:`） |
| Windows 専用/GUI | Office, Chrome, MySQL, Podman, Zen, Cinema4D, Weka, MATLAB… | **winget(DSC)** |
| 野良/残骸 | nvm-windows, choco 一部, Python 3.10/3.13, pyenv, `gopls` 残骸, lefthook, PATH 残骸(`node_mod`) | 移行後**撤去** |

## 9. 削除/変更履歴

- 2026-10-15: `Programs\Python310` 削除 + User PATH 2 件除去
- 2026-10-15: `~/.pyenv`（pyenv-win + 3.10/3.11/3.12, 452MB）削除。プロジェクトは `backup-pyenv-2026-10-15/` へ退避（58 files / 0.61MB）
- 2026-10-15: 方針確定 — Python=3.14系 / Node=26系 / Go=1.27.2 / lefthook→hk

## 10. 生データファイル

`inventory-winget-ids.txt`, `inventory-winget-clean.txt`, `inventory-winget.txt`, `winget-export.json`, `inventory-choco.txt`, `inventory-npm-global.txt`, `inventory-pip.txt`, `inventory-pip-user.txt`, `inventory-nvm.txt`, `inventory-path-user.txt`, `inventory-path-exes.txt`, `inventory-sweep-A〜D.txt`, `backup-pyenv-2026-10-15/`
