# Vorzex Geliştirme Aracı: yönetim panelinin Geliştirme sekmesindeki düğmeler bu aracı "vorzex-gelistir:" adresiyle
# çağırır (kur.cmd bir kez kurar). Yalnız aşağıdaki sabit işler yapılır; adresten başka komut alınmaz:
#   ac/panel, ac/oyun      depo bilgisayarda yoksa GitHub'dan çeker, "gelistirme" dalına geçer, VS Code'u açar
#   onizle/oyun            oyun projesini Unity'de açar (oyna, dene)
#   canli/panel, canli/oyun  GitHub'daki "gelistirme" dalını "main"e aktarır (onay ister); oyunda istenirse APK derler
#   dene                   kurulumu ve bulunan araçları gösterir
# Git girişi bilgisayardakini kullanır (GitHub Desktop / Git Credential Manager); panele şifre ya da anahtar girilmez.
# Klasörler: %LOCALAPPDATA%\VorzexGelistirme\ayar.json (yoksa %USERPROFILE%\VorzexGelistirme\<proje>).
param([string]$Adres = "")

$ErrorActionPreference = "Continue"
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
try { $Host.UI.RawUI.WindowTitle = "Vorzex Geliştirme Aracı" } catch {}

$Kok = if ($env:VX_AYAR_KLASORU) { $env:VX_AYAR_KLASORU } else { Join-Path $env:LOCALAPPDATA "VorzexGelistirme" }
$AyarYolu = Join-Path $Kok "ayar.json"
$Dal = "gelistirme"
$Projeler = @{
    panel = @{ ad = "Yönetim paneli"; url = "https://github.com/ahmetdagbasiclaude-hub/vorzex-panel.git" }
    oyun  = @{ ad = "Oyun"; url = "https://github.com/ahmetdagbasiclaude-hub/oyunlar-m.git" }
}

function Yaz([string]$m, [string]$renk = "Gray") { Write-Host $m -ForegroundColor $renk }
function Bekle { if (-not $env:VX_ONAY) { Yaz ""; [void](Read-Host "Kapatmak için Enter'a bas") } }
function Bitti([string]$m) { Yaz ""; Yaz $m "Green"; Bekle; exit 0 }
function Hata([string]$m) { Yaz ""; Yaz "HATA: $m" "Red"; Bekle; exit 1 }
function Onay([string]$soru) {
    $c = if ($env:VX_ONAY) { $env:VX_ONAY } else { Read-Host "$soru (E/H)" }
    return $c.Trim().ToLowerInvariant() -in @("e", "evet", "y", "yes")
}

# ---- Ayar: proje klasörleri ----
function AyarOku {
    $h = @{}
    if (Test-Path $AyarYolu) {
        try {
            $j = Get-Content $AyarYolu -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $j.PSObject.Properties) { $h[$p.Name] = @{ yol = $p.Value.yol; url = $p.Value.url } }
        } catch { Yaz "Uyarı: ayar dosyası okunamadı ($AyarYolu), varsayılanlar kullanılıyor." "Yellow" }
    }
    return $h
}
function UrlAyni($a, $b) { $n = { param($x) ("$x".Trim().TrimEnd("/") -replace "\.git$", "").ToLowerInvariant() }; return (& $n $a) -eq (& $n $b) }
# Ayarda yoksa bilgisayarda zaten çekilmiş depoyu arar (X:\oyunlarım..., GitHub Desktop'ın Belgeler\GitHub klasörü);
# bulursa ayara yazar ki bir daha aranmasın. Bulamazsa %USERPROFILE%\VorzexGelistirme\<proje> (ilk açılışta çekilir).
function MevcutDepoyuBul([string]$ad, [string]$url) {
    if (-not $Git) { return $null }
    $depoAdi = [IO.Path]::GetFileNameWithoutExtension(($url.TrimEnd("/") -split "/")[-1])
    $adaylar = @((Join-Path ([Environment]::GetFolderPath("MyDocuments")) "GitHub\$depoAdi"))
    foreach ($s in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
        $adaylar += if ($ad -eq "panel") { Join-Path $s.Root "oyunlarım\vorzex-panel" } else { Join-Path $s.Root "oyunlarım" }
        $adaylar += Join-Path $s.Root $depoAdi
    }
    foreach ($a in $adaylar) {
        if (-not (Test-Path (Join-Path $a ".git"))) { continue }
        if (UrlAyni (& $Git -C $a remote get-url origin 2>$null) $url) { return $a }
    }
    return $null
}
function Proje([string]$ad) {
    $a = (AyarOku)[$ad]
    $url = if ($a -and $a.url) { $a.url } else { $Projeler[$ad].url }
    $yol = if ($a -and $a.yol) { $a.yol } else { MevcutDepoyuBul $ad $url }
    if ($yol -and -not ($a -and $a.yol)) { YolKaydet $ad $yol $url; Yaz "Bilgisayarda bulundu: $yol" "Gray" }
    if (-not $yol) { $yol = Join-Path $env:USERPROFILE "VorzexGelistirme\$ad" }
    return @{ ad = $Projeler[$ad].ad; yol = $yol; url = $url }
}
function YolKaydet([string]$ad, [string]$yol, [string]$url) {
    $h = AyarOku
    $h[$ad] = @{ yol = $yol; url = $url }
    New-Item -ItemType Directory -Force $Kok | Out-Null
    $h | ConvertTo-Json | Set-Content $AyarYolu -Encoding UTF8
}

# ---- Araçlar ----
function GitBul {
    $g = Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($g) { return $g.Source }
    $adaylar = @("$env:ProgramFiles\Git\cmd\git.exe") +
        @(Get-ChildItem "$env:LOCALAPPDATA\GitHubDesktop\app-*\resources\app\git\cmd\git.exe" -ErrorAction SilentlyContinue |
          Sort-Object FullName -Descending | ForEach-Object { $_.FullName })
    foreach ($a in $adaylar) { if ($a -and (Test-Path $a)) { return $a } }
    return $null
}
function KodBul {
    $k = Get-Command code -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($k) { return $k.Source }
    foreach ($a in @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd", "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd")) {
        if (Test-Path $a) { return $a }
    }
    return $null
}
function UnityBul([string]$surum) {
    $adaylar = @("$env:ProgramFiles\Unity\Hub\Editor\$surum\Editor\Unity.exe")
    $ikinci = Join-Path $env:APPDATA "UnityHub\secondaryInstallPath.json"
    if (Test-Path $ikinci) {
        try { $k = (Get-Content $ikinci -Raw | ConvertFrom-Json); if ($k) { $adaylar += Join-Path $k "$surum\Editor\Unity.exe" } } catch {}
    }
    foreach ($a in $adaylar) { if ($a -and (Test-Path $a)) { return $a } }
    return $null
}

$Git = GitBul
$Yol = ""
# Git'i proje klasöründe çalıştırır; çıktısı ekrana gider, başarılıysa $true döner.
function Calis { & $Git -C $script:Yol @args | Out-Host; return ($LASTEXITCODE -eq 0) }
# Git çıktısını döner (hata ise $null; hata yazısı gizlenir).
function Oku { $o = & $Git -C $script:Yol @args 2>$null; if ($LASTEXITCODE -ne 0) { return $null }; return (($o | Out-String).Trim()) }
function Kirli { return [bool](Oku status --porcelain) }

function DepoyaGir([string]$ad, [bool]$yoksaCek) {
    $p = Proje $ad
    $script:Yol = $p.yol
    Yaz "$($p.ad): $($p.yol)" "Cyan"
    if (-not (Test-Path (Join-Path $p.yol ".git"))) {
        if (-not $yoksaCek) { Hata "Bu bilgisayarda $($p.ad) klasörü yok. Önce panelden 'VS Code ile geliştir'e bas (GitHub'dan çeker)." }
        if ((Test-Path $p.yol) -and (Get-ChildItem $p.yol -Force | Select-Object -First 1)) { Hata "Klasör var ama git deposu değil: $($p.yol)" }
        Yaz "Bilgisayarda yok: GitHub'dan çekiliyor ($($p.url)). Büyük depoda birkaç dakika sürebilir..." "Cyan"
        New-Item -ItemType Directory -Force (Split-Path $p.yol) | Out-Null
        & $Git clone $p.url $p.yol | Out-Host
        if ($LASTEXITCODE -ne 0) { Hata "Depo çekilemedi. İnternetini ve GitHub girişini (GitHub Desktop) kontrol et." }
        YolKaydet $ad $p.yol $p.url
    } else {
        $u = Oku remote get-url origin
        $norm = { param($x) ("$x".Trim().TrimEnd("/") -replace "\.git$", "").ToLowerInvariant() }
        if ((& $norm $u) -ne (& $norm $p.url)) { Hata "Bu klasör başka bir depoya bağlı ($u). Beklenen: $($p.url)" }
    }
    return $p
}

# ---- İşler ----
function Gelistir([string]$ad) {
    $p = DepoyaGir $ad $true
    Yaz "GitHub'dan güncelleniyor..."
    if (-not (Calis fetch origin --prune)) { Yaz "Uyarı: GitHub'a bağlanılamadı; yereldeki hâliyle açılıyor." "Yellow" }
    $su = Oku branch --show-current
    if ($su -ne $Dal) {
        if (Kirli) {
            Yaz "Uyarı: '$su' dalında kaydedilmemiş değişiklik var; dal değiştirilmedi. Değişiklikleri kaydet (commit) ya da geri al, sonra tekrar bas." "Yellow"
        } elseif (Oku rev-parse --verify --quiet "refs/heads/$Dal") {
            $null = Calis checkout $Dal
        } elseif (Oku rev-parse --verify --quiet "refs/remotes/origin/$Dal") {
            $null = Calis checkout -b $Dal --track "origin/$Dal"
        } else {
            Yaz "'$Dal' dalı yok: main'den oluşturulup GitHub'a gönderiliyor..." "Cyan"
            if (-not (Calis checkout -b $Dal origin/main)) { Hata "'$Dal' dalı oluşturulamadı." }
            if (-not (Calis push -u origin $Dal)) { Yaz "Uyarı: dal GitHub'a gönderilemedi; VS Code'da 'Publish Branch' ile gönder." "Yellow" }
        }
    }
    if ((Oku branch --show-current) -eq $Dal -and -not (Oku rev-parse --verify --quiet "refs/remotes/origin/$Dal")) {
        Yaz "'$Dal' dalı GitHub'da yok: gönderiliyor..." "Cyan"
        if (-not (Calis push -u origin $Dal)) { Yaz "Uyarı: dal GitHub'a gönderilemedi; VS Code'da 'Publish Branch' ile gönder." "Yellow" }
    }
    if ((Oku branch --show-current) -eq $Dal -and -not (Kirli) -and (Oku rev-parse --verify --quiet "refs/remotes/origin/$Dal")) {
        if (-not (Oku rev-parse --abbrev-ref "@{u}")) { $null = Calis branch --set-upstream-to "origin/$Dal" }
        if (-not (Calis merge --ff-only "origin/$Dal")) { Yaz "Uyarı: GitHub'daki '$Dal' ile yereldeki ayrışmış; VS Code'da Senkronize et (Sync)." "Yellow" }
    }
    Yaz ""
    Yaz "Dal: $(Oku branch --show-current)" "Cyan"
    $kod = KodBul
    if (-not $kod) { Start-Process "https://code.visualstudio.com/"; Hata "VS Code kurulu değil: açılan sayfadan kur, sonra tekrar bas." }
    if ($env:VX_KOD_ACMA) { Yaz "(deneme) VS Code açılacaktı: $kod `"$($p.yol)`"" } else { & $kod $p.yol }
    Yaz "Geliştirmeyi bitirince VS Code'da değişiklikleri kaydet (commit) ve gönder (Sync/Push); sonra panelden Önizle ve Canlıya al." "Gray"
    Bitti "VS Code açıldı: $($p.ad) ($(Oku branch --show-current) dalı)."
}

# Unity Türkçe karakterli yolda sorun çıkarır: yol ASCII değilse aynı sürücüde kavşak (junction) açılır.
function AsciiYol([string]$yol) {
    if ($yol -notmatch '[^\x00-\x7F]') { return $yol }
    $kok = [IO.Path]::GetPathRoot($yol)
    foreach ($ad in @("VorzexProje", "VorzexProje_Gelistirme")) {
        $k = Join-Path $kok $ad
        if (Test-Path $k) {
            $hedef = @((Get-Item $k -Force).Target) | Select-Object -First 1
            if ($hedef -and ("$hedef".TrimEnd("\") -ieq $yol.TrimEnd("\"))) { return $k }
            continue
        }
        New-Item -ItemType Junction -Path $k -Target $yol | Out-Null
        return $k
    }
    return $yol
}
function UnityHazirla {
    $proje = Join-Path $script:Yol "BattleRoyale"
    $pv = Join-Path $proje "ProjectSettings\ProjectVersion.txt"
    if (-not (Test-Path $pv)) { Hata "Unity projesi bulunamadı: $proje" }
    $surum = ((Get-Content $pv | Select-String "m_EditorVersion:\s*(\S+)").Matches[0].Groups[1].Value)
    $unity = UnityBul $surum
    if (-not $unity) { Hata "Unity $surum kurulu değil: Unity Hub'dan bu sürümü kur." }
    if (Get-Process Unity -ErrorAction SilentlyContinue) { Hata "Unity zaten açık: önce kapat (aynı anda iki Unity çalışmaz)." }
    return @{ unity = $unity; proje = (AsciiYol $proje); surum = $surum }
}

function OyunOnizle {
    $null = DepoyaGir "oyun" $false
    $su = Oku branch --show-current
    if ($su -ne $Dal) { Yaz "Uyarı: klasör '$su' dalında ('$Dal' değil)." "Yellow" }
    if (Kirli) { Yaz "Not: kaydedilmemiş değişiklikler de önizlemede görünür." "Gray" }
    $u = UnityHazirla
    Yaz "Unity $($u.surum) açılıyor: $($u.proje)" "Cyan"
    if ($env:VX_KOD_ACMA) { Yaz "(deneme) Unity açılacaktı: $($u.unity) -projectPath `"$($u.proje)`"" }
    else { Start-Process $u.unity -ArgumentList @("-projectPath", "`"$($u.proje)`"") }
    Bitti "Unity açılıyor (ilk açılış birkaç dakika sürebilir). Giriş sahnesinden Play'e basıp dene."
}

function ApkDerle {
    $u = UnityHazirla
    $log = Join-Path $Kok "apk.log"
    New-Item -ItemType Directory -Force $Kok | Out-Null
    Yaz "APK derleniyor (15-20 dakika sürebilir; bu pencereyi kapatma)..." "Cyan"
    $s = Start-Process $u.unity -ArgumentList @("-batchmode", "-projectPath", "`"$($u.proje)`"", "-buildTarget", "Android",
        "-executeMethod", "LobiKurucu.ApkCikar", "-quit", "-logFile", "`"$log`"") -Wait -PassThru
    $satir = Select-String -Path $log -Pattern "\[Boran\] APK:" -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($s.ExitCode -ne 0 -or -not $satir -or "$satir" -notmatch "Succeeded") {
        Select-String -Path $log -Pattern "error CS|BuildFailed|Exception" -ErrorAction SilentlyContinue | Select-Object -First 5 | ForEach-Object { Yaz "$($_.Line)" "Red" }
        Hata "APK derlenemedi. Ayrıntı: $log"
    }
    Yaz $satir.Line "Green"
    $apk = Join-Path $u.proje "Builds\VorzexMobile.apk"
    if (Test-Path $apk) { Start-Process explorer.exe "/select,`"$apk`"" }
}

function Canli([string]$ad) {
    $p = DepoyaGir $ad $false
    Yaz "GitHub'dan güncelleniyor..."
    if (-not (Calis fetch origin --prune)) { Hata "GitHub'a bağlanılamadı." }
    if (-not (Oku rev-parse --verify --quiet "refs/remotes/origin/$Dal")) { Hata "GitHub'da '$Dal' dalı yok. Önce 'VS Code ile geliştir' ile geliştir ve gönder." }
    if (Oku rev-parse --verify --quiet "refs/heads/$Dal") {
        $gonderilmemis = [int](Oku rev-list --count "origin/$Dal..$Dal")
        if ($gonderilmemis -gt 0) { Hata "Bu bilgisayarda GitHub'a gönderilmemiş $gonderilmemis değişiklik var. VS Code'da önce gönder (Sync/Push), sonra tekrar bas." }
        if ((Oku branch --show-current) -eq $Dal -and (Kirli)) { Yaz "Uyarı: kaydedilmemiş (commit edilmemiş) değişiklikler canlıya gitmez." "Yellow" }
    }
    $n = [int](Oku rev-list --count "origin/main..origin/$Dal")
    if ($n -eq 0) { Bitti "Canlıya alınacak yeni değişiklik yok: main zaten güncel." }
    Yaz ""
    Yaz "Canlıya alınacak $n değişiklik ($($p.ad)):" "Cyan"
    & $Git -C $Yol log --oneline --no-decorate -n 30 "origin/main..origin/$Dal" | Out-Host
    Yaz ""
    if (-not (Onay "Bunlar canlıya alınsın mı?")) { Bitti "Vazgeçildi; hiçbir şey değişmedi." }

    & $Git -C $Yol merge-base --is-ancestor origin/main "origin/$Dal"
    $duz = ($LASTEXITCODE -eq 0)
    if ($duz) { $hedef = Oku rev-parse "origin/$Dal" }
    else {
        # main'de gelistirme'de olmayan değişiklik var: klasöre dokunmadan birleştir (çakışma varsa durur).
        $agac = Oku merge-tree --write-tree origin/main "origin/$Dal"
        if (-not $agac) {
            Yaz "Çakışan dosyalar:" "Red"
            & $Git -C $Yol merge-tree --write-tree --name-only origin/main "origin/$Dal" | Select-Object -Skip 1 | Out-Host
            Hata "main ile $Dal çakışıyor. VS Code'da main'i $Dal dalına birleştirip (merge) çakışmaları çöz, gönder, sonra tekrar bas."
        }
        $agac = ($agac -split "`r?`n")[0]
        if (-not (Oku config user.name)) { $env:GIT_AUTHOR_NAME = "Vorzex Geliştirme Aracı"; $env:GIT_COMMITTER_NAME = $env:GIT_AUTHOR_NAME }
        if (-not (Oku config user.email)) { $env:GIT_AUTHOR_EMAIL = "gelistirme@vorzex.local"; $env:GIT_COMMITTER_EMAIL = $env:GIT_AUTHOR_EMAIL }
        $hedef = Oku commit-tree $agac -p origin/main -p "origin/$Dal" -m "Canlıya al: $Dal -> main"
        if (-not $hedef) { Hata "Birleştirme kaydı oluşturulamadı." }
    }
    if (-not (Calis push origin "${hedef}:refs/heads/main")) { Hata "main'e gönderilemedi (yetki yok ya da bu arada başkası değiştirdi). Tekrar dene." }
    if (-not $duz) {
        # gelistirme de main ile aynı olsun (sonraki seferde düz ilerler); bu arada biri gönderdiyse dokunulmaz.
        $null = Calis push origin "${hedef}:refs/heads/$Dal"
        $null = Calis fetch origin
        if ((Oku branch --show-current) -eq $Dal -and -not (Kirli)) { $null = Calis merge --ff-only "origin/$Dal" }
    }
    Yaz ""
    Yaz "Canlıya alındı: $($p.ad) main güncellendi." "Green"
    if ($ad -eq "panel") { Bitti "Panel 1-2 dakika içinde yayında (sayfayı Ctrl+F5 ile yenile)." }
    Yaz "Oyuncular yeni hâli yeni APK ile alır. Not: her yeni APK'da Yonetim.SurumKodu bir artırılmalı." "Gray"
    if (Onay "APK şimdi derlensin mi?") {
        if ((Oku branch --show-current) -ne $Dal -or (Kirli) -or (Oku rev-parse HEAD) -ne (Oku rev-parse "origin/$Dal")) {
            Hata "APK bu klasördeki hâlden derlenir; klasör canlıdaki ($Dal) hâlle aynı değil. VS Code'da senkronize et (Sync), sonra tekrar dene."
        }
        ApkDerle
        Bitti "APK hazır (açılan klasörde)."
    }
    Bitti "Tamam."
}

function Dene {
    Yaz "Vorzex Geliştirme Aracı çalışıyor." "Green"
    Yaz "Git:     $(if ($Git) { $Git } else { 'YOK (GitHub Desktop ya da Git kur)' })"
    $k = KodBul; Yaz "VS Code: $(if ($k) { $k } else { 'YOK (code.visualstudio.com)' })"
    foreach ($ad in @("panel", "oyun")) {
        $p = Proje $ad
        $var = Test-Path (Join-Path $p.yol ".git")
        Yaz ("{0,-15} {1} {2}" -f "$($p.ad):", $p.yol, $(if ($var) { "(var)" } else { "(yok: ilk açılışta GitHub'dan çekilir)" }))
    }
    New-Item -ItemType Directory -Force $Kok | Out-Null
    Set-Content (Join-Path $Kok "son-deneme.txt") (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Encoding UTF8
    Bitti "Kurulum tamam."
}

# ---- Adres: "vorzex-gelistir:ac/panel" (tarayıcı "vorzex-gelistir://ac/panel/" da gönderebilir) ----
$is = ([Uri]::UnescapeDataString($Adres) -replace '^vorzex-gelistir:(//)?', '').Trim().Trim('/').ToLowerInvariant()
Yaz "Vorzex Geliştirme Aracı · $is" "DarkGray"
if (-not $Git -and $is -ne "dene") { Start-Process "https://desktop.github.com/"; Hata "Git bulunamadı: GitHub Desktop'ı kur (açılan sayfa), sonra tekrar bas." }
switch -regex ($is) {
    '^ac/(panel|oyun)$' { Gelistir $Matches[1]; break }
    '^onizle/oyun$' { OyunOnizle; break }
    '^canli/(panel|oyun)$' { Canli $Matches[1]; break }
    '^dene$' { Dene; break }
    default { Hata "Bilinmeyen istek: '$is'" }
}
# Buraya gelinmemeli (her iş Bitti ya da Hata ile çıkar).
Hata "Beklenmeyen durum: iş tamamlanmadı."
