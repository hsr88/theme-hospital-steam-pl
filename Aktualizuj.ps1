[CmdletBinding()]
param([string]$GamePath,[switch]$ConfirmInstall)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
function Hash([string]$Path){
 $sha=[Security.Cryptography.SHA256]::Create();$s=[IO.File]::OpenRead($Path)
 try{[BitConverter]::ToString($sha.ComputeHash($s)).Replace('-','').ToLowerInvariant()}
 finally{$s.Dispose();$sha.Dispose()}
}
try{
 if(-not $GamePath){
  $roots=@('C:\Program Files (x86)\Steam','C:\Program Files\Steam')
  $reg=Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue
  if($reg -and $reg.SteamPath){$roots+=$reg.SteamPath}
  $libs=@($roots)
  foreach($root in $roots){
   $vdf=Join-Path $root 'steamapps\libraryfolders.vdf'
   if(Test-Path -LiteralPath $vdf){foreach($m in [regex]::Matches([IO.File]::ReadAllText($vdf),'"path"\s+"([^"]+)"')){$libs+=$m.Groups[1].Value.Replace('\\','\')}}
  }
  $found=@(foreach($lib in ($libs|Select-Object -Unique)){
   $acf=Join-Path $lib 'steamapps\appmanifest_2229820.acf'
   if(Test-Path -LiteralPath $acf){$m=[regex]::Match([IO.File]::ReadAllText($acf),'"installdir"\s+"([^"]+)"');if($m.Success){Join-Path (Join-Path $lib 'steamapps\common') $m.Groups[1].Value}}
  })
  if($found.Count -ne 1){throw 'Podaj -GamePath.'};$GamePath=$found[0]
 }
 $GamePath=(Resolve-Path -LiteralPath $GamePath).Path
 $stateDir=Join-Path $GamePath '.thpl';$statePath=Join-Path $stateDir 'state.json'
 $oldRoot=Join-Path $PSScriptRoot 'aktualizacja-z-0.1'
 $old=Get-Content -LiteralPath (Join-Path $oldRoot 'patch.json') -Raw -Encoding UTF8|ConvertFrom-Json
 $new=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'patch.json') -Raw -Encoding UTF8|ConvertFrom-Json
 $state=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8|ConvertFrom-Json
 if($state.status -ne 'installed' -or $state.version -ne '0.1-beta'){throw 'Ten aktualizator wymaga zainstalowanej wersji 0.1-beta. Dla czystej gry uzyj Instaluj.cmd.'}
 if(Get-Process -Name DOSBox,HOSPITAL,'Theme Hospital' -ErrorAction SilentlyContinue){throw 'Zamknij gre i DOSBox.'}
 if((Hash (Join-Path $GamePath 'HOSPITAL.EXE')) -ne $new.exe_sha256){throw 'Nieznana wersja gry.'}
 foreach($f in $new.files){
  if($f.path -notmatch '^(DATA/LANG-0\.DAT|QDATA/FONT[0-9]+V\.(DAT|TAB)|QDATAM/FONT[0-9]+M\.(DAT|TAB)|LEVELS/(EASY|FULL|HARD|NET)00\.SAM)$'){throw 'Niedozwolona sciezka.'}
  foreach($base in @($GamePath,(Join-Path $stateDir 'backup'))){
   $cur=Join-Path $base $f.path
   while($cur){
    if((Test-Path -LiteralPath $cur) -and ((Get-Item -LiteralPath $cur -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Dowiazanie w katalogu gry lub kopii.'}
    $cur=[IO.Path]::GetDirectoryName($cur)
   }
  }
  $previous=@($old.files|Where-Object path -eq $f.path)
  $source=Join-Path $GamePath $f.path
  if($previous.Count){
   if((Hash $source) -ne $previous[0].after){throw "Zmieniony plik: $($f.path)"}
   $source=Join-Path (Join-Path $stateDir 'backup') $f.path
  }
  if((Hash $source) -ne $f.before){throw "Brak zgodnego oryginalu: $($f.path)"}
  if(Test-Path -LiteralPath (Join-Path (Join-Path $GamePath 'cloud_saves') $f.path)){throw 'Konflikt pliku z cloud_saves.'}
 }
 if(-not $ConfirmInstall){
  Write-Host 'Aktualizacja 0.1 -> 0.2. Zachowa oryginalny backup i kopie obecnego spolszczenia.'
  if((Read-Host 'Wpisz TAK, aby aktualizowac') -cne 'TAK'){exit 0}
 }
 $history=Join-Path $stateDir 'history'
 if((Test-Path -LiteralPath $history) -and ((Get-Item -LiteralPath $history -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Niedozwolone dowiazanie historii.'}
 $snapshot=Join-Path $history ('0.1-'+[guid]::NewGuid().ToString('N'))
 $null=New-Item -ItemType Directory -Path $snapshot
 foreach($f in $old.files){
  if(-not @($new.files|Where-Object path -eq $f.path).Count){throw 'Plik poprzedniej wersji poza manifestem.'}
  $source=Join-Path $GamePath $f.path;$target=Join-Path $snapshot $f.path
  $null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force
  [IO.File]::Copy($source,$target,$false)
  if((Hash $target) -ne $f.after){throw 'Niepoprawna kopia poprzedniej wersji.'}
 }
 [IO.File]::Copy($statePath,(Join-Path $snapshot 'state.json'),$false)
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $oldRoot 'Spolszczenie.ps1') -Action Uninstall -GamePath $GamePath -ConfirmInstall
 if($LASTEXITCODE -ne 0){throw 'Nie udalo sie bezpiecznie przywrocic oryginalow. Zachowano backup.'}
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Spolszczenie.ps1') -Action Install -GamePath $GamePath -ConfirmInstall
 if($LASTEXITCODE -ne 0){
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $oldRoot 'Spolszczenie.ps1') -Action Install -GamePath $GamePath -ConfirmInstall
  if($LASTEXITCODE -ne 0){throw 'Aktualizacja nieudana. Zachowano oryginaly i historie. Sprawdz dziennik .thpl/state.json.'}
  throw 'Aktualizacja nieudana; przywrocono wersje 0.1-beta.'
 }
 Write-Host "Zaktualizowano do 0.2-beta. Oryginaly: .thpl\backup. Poprzednia wersja: $snapshot"
}catch{Write-Error $_;exit 1}
