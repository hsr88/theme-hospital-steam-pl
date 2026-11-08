[CmdletBinding()]
param(
 [ValidateSet('Check','Install','Uninstall')][string]$Action='Check',
 [string]$GamePath,
 [switch]$ConfirmInstall
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
Add-Type 'public static class THPLFile { public static void Replace(string source,string target) { System.IO.File.Replace(source,target,null); } }'
function Hash([string]$Path) {
 $algorithm=[Security.Cryptography.SHA256]::Create();$stream=[IO.File]::OpenRead($Path)
 try {return [BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-','').ToLowerInvariant()}
 finally {$stream.Dispose();$algorithm.Dispose()}
}
function SafePath([string]$Root,[string]$Relative) {
 if ($Relative -notmatch '^(DATA/LANG-0\.DAT|QDATA/FONT[0-9]+V\.(DAT|TAB)|QDATAM/FONT[0-9]+M\.(DAT|TAB)|LEVELS/(EASY|FULL|HARD|NET)00\.SAM)$') {throw "Niedozwolona sciezka: $Relative"}
 $p=[IO.Path]::GetFullPath((Join-Path $Root $Relative))
 $prefix=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
 if(-not $p.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Sciezka poza katalogiem gry'}
 $cur=$p
 while($cur){
  if((Test-Path -LiteralPath $cur) -and ((Get-Item -LiteralPath $cur -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw "Dowiazanie/reparse point: $cur"}
  $cur=[IO.Path]::GetDirectoryName($cur)
 }
 return $p
}
function FindGame {
 $bases=@('C:\Program Files (x86)\Steam','C:\Program Files\Steam')
 $reg=Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue
 if($reg -and $reg.SteamPath){$bases+=$reg.SteamPath}
 $libs=@($bases)
 foreach($base in $bases){
  $vdf=Join-Path $base 'steamapps\libraryfolders.vdf'
  if(Test-Path -LiteralPath $vdf){
   foreach($m in [regex]::Matches([IO.File]::ReadAllText($vdf),'"path"\s+"([^"]+)"')){$libs+=$m.Groups[1].Value.Replace('\\','\')}
  }
 }
 $found=@(foreach($lib in ($libs|Select-Object -Unique)){
  $manifest=Join-Path $lib 'steamapps\appmanifest_2229820.acf'
  if(Test-Path -LiteralPath $manifest){
   $m=[regex]::Match([IO.File]::ReadAllText($manifest),'"installdir"\s+"([^"]+)"')
   if($m.Success){Join-Path (Join-Path $lib 'steamapps\common') $m.Groups[1].Value}
  }
 })
 if($found.Count -ne 1){throw 'Podaj -GamePath z pelna sciezka do Theme Hospital.'}
 return $found[0]
}
function WriteJson($Object,[string]$Path){
 $temp=$Path+'.new'
 [IO.File]::WriteAllText($temp,($Object|ConvertTo-Json -Depth 20),(New-Object Text.UTF8Encoding($false)))
 if(Test-Path -LiteralPath $Path){[THPLFile]::Replace($temp,$Path)}else{[IO.File]::Move($temp,$Path)}
}
function BuildFile($Entry,[string]$Source,[string]$Destination,[string]$TempRoot){
 if($Entry.path -eq 'DATA/LANG-0.DAT'){
  $bytes=[IO.File]::ReadAllBytes($Source);$n=[BitConverter]::ToUInt16($bytes,0)
  if($n -ne 68){throw 'Nieprawidlowy naglowek LANG'}
  $stream=New-Object IO.MemoryStream
  try {
   $stream.Write($bytes,0,138);$pos=138;$cp=[Text.Encoding]::GetEncoding(437)
   for($s=1;$s -le $n;$s++){
    $count=[BitConverter]::ToUInt16($bytes,$s*2)
    for($i=1;$i -le $count;$i++){
     $start=$pos;while($pos -lt $bytes.Length -and $bytes[$pos] -ne 0){$pos++}
     if($pos -eq $bytes.Length){throw 'Brak terminatora tekstu'}
     $property=$Entry.strings.PSObject.Properties["${s}:$i"]
     if($property){
      foreach($c in $property.Value.ToCharArray()){
       $mapped=$script:patch.encoding.PSObject.Properties[[string][int]$c]
       if($mapped){$stream.WriteByte([byte]$mapped.Value)}else{
        $encoded=$cp.GetBytes([string]$c)
        if($encoded.Length -ne 1 -or $cp.GetString($encoded) -cne [string]$c){throw 'Nieobslugiwany znak'}
        $stream.WriteByte($encoded[0])
       }
      }
     }else{$stream.Write($bytes,$start,$pos-$start)}
     $stream.WriteByte(0);$pos++
    }
   }
   if($pos -ne $bytes.Length){throw 'Nadmiarowe dane LANG'}
   [IO.File]::WriteAllBytes($Destination,$stream.ToArray())
  }finally{$stream.Dispose()}
 }else{
  $decoded=$Source
  if($Entry.rnc){
   $decoded=Join-Path $TempRoot 'decoded.bin'
   & (Join-Path $PSScriptRoot 'rnc_decode.exe') $Source $decoded | Out-Null
   if($LASTEXITCODE -ne 0){throw "Blad RNC: $($Entry.path)"}
  }
  if((Hash $decoded) -ne $Entry.decoded){throw 'Niezgodny hash po dekompresji'}
  $bytes=[IO.File]::ReadAllBytes($decoded);$stream=New-Object IO.MemoryStream
  try {
   foreach($op in $Entry.ops){
    if($op.PSObject.Properties['copy']){
     if($op.copy -lt 0 -or $op.length -lt 0 -or ($op.copy+$op.length) -gt $bytes.Length){throw 'Nieprawidlowy zakres delty'}
     $stream.Write($bytes,[int]$op.copy,[int]$op.length)
    }else{$literal=[Convert]::FromBase64String($op.data);$stream.Write($literal,0,$literal.Length)}
   }
   [IO.File]::WriteAllBytes($Destination,$stream.ToArray())
  }finally{$stream.Dispose()}
 }
 if((Hash $Destination) -ne $Entry.after){throw "Nieprawidlowy wynik: $($Entry.path)"}
}
$tempRoot=$null;$lock=$null
try {
 $script:patch=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'patch.json') -Raw -Encoding UTF8|ConvertFrom-Json
 if(-not $GamePath){$GamePath=FindGame}
 $GamePath=(Resolve-Path -LiteralPath $GamePath).Path
 Write-Host "Theme Hospital PL $($patch.version) | $Action | $GamePath"
 $stateDir=Join-Path $GamePath '.thpl';$statePath=Join-Path $stateDir 'state.json'
 $exe=Join-Path $GamePath 'HOSPITAL.EXE'
 if((Hash $exe) -ne $patch.exe_sha256){throw 'Nieznana wersja HOSPITAL.EXE. Nie zmieniono plikow.'}
 $seen=@{}
 foreach($f in $patch.files){
  $null=SafePath $GamePath $f.path
  if($seen.ContainsKey($f.path)){throw 'Powtorzony plik w pakiecie'};$seen[$f.path]=$true
 }
 if((Test-Path -LiteralPath $stateDir) -and ((Get-Item -LiteralPath $stateDir -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Niedozwolone dowiazanie backupu'}
 if($Action -eq 'Uninstall'){
  if(-not (Test-Path -LiteralPath $statePath)){throw 'Brak manifestu instalacji. Nic nie przywrocono.'}
  $state=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8|ConvertFrom-Json
  if($state.status -eq 'restored'){Write-Host 'Spolszczenie juz odinstalowane.';exit 0}
  if($state.version -ne $patch.version -or $state.files.Count -ne $patch.files.Count){throw 'Niezgodny manifest backupu'}
  foreach($f in $patch.files){
   $saved=@($state.files|Where-Object path -eq $f.path)
   if($saved.Count -ne 1 -or $saved[0].before -ne $f.before -or $saved[0].after -ne $f.after){throw 'Niezgodne wpisy backupu'}
   $backup=SafePath (Join-Path $stateDir 'backup') $f.path
   if((Hash $backup) -ne $f.before){throw "Uszkodzony backup: $($f.path)"}
   $actual=Hash (SafePath $GamePath $f.path)
   if($actual -ne $f.after -and $actual -ne $f.before){throw "Konflikt po aktualizacji lub obcej zmianie: $($f.path). Nic nie nadpisano."}
  }
 }else{
  if(Test-Path -LiteralPath $statePath){
   $state=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8|ConvertFrom-Json
   if($state.status -ne 'restored'){throw 'Wykryto instalacje lub niedokonczona operacje. Uzyj Uninstall.'}
  }
  if([IO.File]::ReadAllText((Join-Path $GamePath 'HOSPITAL.CFG')) -notmatch '(?im)^LANGUAGE=ENG\s*$'){throw 'Wybierz jezyk English w Steam.'}
  foreach($f in $patch.files){
   if((Hash (SafePath $GamePath $f.path)) -ne $f.before){throw "Nieznany lub zmodyfikowany plik: $($f.path)"}
   if(Test-Path -LiteralPath (Join-Path (Join-Path $GamePath 'cloud_saves') $f.path)){throw "Konflikt nakladki cloud_saves: $($f.path)"}
  }
  if(Test-Path -LiteralPath (Join-Path $GamePath 'cloud_saves\HOSPITAL.CFG')){throw 'Konfiguracja w cloud_saves wymaga osobnej kontroli. Nie zmieniono zapisow.'}
 }
 if($Action -eq 'Check'){Write-Host 'OK: zgodna instalacja. Tryb sprawdzania nie zapisuje niczego do gry.';exit 0}
 if(Get-Process -Name DOSBox,HOSPITAL,'Theme Hospital' -ErrorAction SilentlyContinue){throw 'Zamknij gre i DOSBox przed instalacja/odinstalowaniem.'}
 if(-not $ConfirmInstall){
  Write-Host 'Wersja beta. Operacja zmieni tylko teksty i fonty; najpierw sprawdzi kopie zapasowe.'
  if((Read-Host 'Wpisz TAK, aby wykonac operacje') -cne 'TAK'){Write-Host 'Anulowano.';exit 0}
 }
 $null=New-Item -ItemType Directory -Path $stateDir -Force
 $lock=[IO.File]::Open((Join-Path $stateDir 'lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 # Recheck after obtaining the lock, before any mutation.
 if(Test-Path -LiteralPath $statePath){
  $latest=Get-Content -LiteralPath $statePath -Raw -Encoding UTF8|ConvertFrom-Json
  if($Action -eq 'Install' -and $latest.status -ne 'restored'){throw 'Inna operacja zmienila stan instalacji'}
 }
 $tempRoot=Join-Path $stateDir ('staging-'+[guid]::NewGuid().ToString('N'))
 $null=New-Item -ItemType Directory -Path $tempRoot
 if($Action -eq 'Install'){
  if((Hash (Join-Path $PSScriptRoot 'rnc_decode.exe')) -ne $patch.rnc_sha256){throw 'Uszkodzone narzedzie RNC'}
  foreach($f in $patch.files){
   $source=SafePath $GamePath $f.path
   if((Hash $source) -ne $f.before){throw 'Plik zmienil sie w czasie operacji'}
   $dest=SafePath $tempRoot $f.path;$null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($dest)) -Force
   BuildFile $f $source $dest $tempRoot
  }
  foreach($f in $patch.files){
   $source=SafePath $GamePath $f.path;$backup=SafePath (Join-Path $stateDir 'backup') $f.path
   $null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($backup)) -Force
   if(Test-Path -LiteralPath $backup){if((Hash $backup) -ne $f.before){throw 'Nie nadpisuje obcej kopii zapasowej'}}else{[IO.File]::Copy($source,$backup,$false)}
   if((Hash $backup) -ne $f.before){throw 'Blad weryfikacji backupu'}
  }
  $state=[pscustomobject]@{version=$patch.version;status='pending';files=@($patch.files|Select-Object path,before,after)}
  WriteJson $state $statePath
  $written=New-Object 'System.Collections.Generic.List[object]'
  try {
   foreach($f in $patch.files){
    $dest=SafePath $GamePath $f.path
    if((Hash $dest) -ne $f.before){throw 'Plik zmieniony podczas instalacji'}
    [THPLFile]::Replace((SafePath $tempRoot $f.path),$dest)
    $written.Add($f)
   }
   $state.status='installed';WriteJson $state $statePath
  }catch{
   $installError=$_
   foreach($f in $written){
    try {
     $dest=SafePath $GamePath $f.path;$backup=SafePath (Join-Path $stateDir 'backup') $f.path
     if((Hash $dest) -eq $f.after -and (Hash $backup) -eq $f.before){
      $restore=Join-Path $tempRoot 'rollback.bin';[IO.File]::Copy($backup,$restore,$true)
      [THPLFile]::Replace($restore,$dest)
     }
    }catch{Write-Warning "Nie udalo sie przywrocic $($f.path). Zachowano dziennik i backup."}
   }
   $recovered=$true
   foreach($f in $patch.files){if((Hash (SafePath $GamePath $f.path)) -ne $f.before){$recovered=$false}}
   if($recovered){$state.status='restored';WriteJson $state $statePath;Write-Warning 'Blad instalacji. Wszystkie pliki gry przywrocono.'}
   else{Write-Warning 'Instalacja przerwana. Uruchom Odinstaluj. Nie usuwaj .thpl.'}
   throw $installError
  }
  Write-Host 'Zainstalowano. Uruchom gre normalnie przez Steam (English). Backup: .thpl\backup'
 }else{
  $state.status='restoring';WriteJson $state $statePath
  foreach($f in $patch.files){
   $dest=SafePath $GamePath $f.path;$backup=SafePath (Join-Path $stateDir 'backup') $f.path
   if((Hash $backup) -ne $f.before){throw 'Backup zmienil sie podczas przywracania'}
   $actual=Hash $dest
   if($actual -eq $f.before){continue}
   if($actual -ne $f.after){throw 'Konflikt podczas przywracania'}
   $temp=Join-Path $tempRoot 'restore.bin';[IO.File]::Copy($backup,$temp,$true)
   [THPLFile]::Replace($temp,$dest)
   if((Hash $dest) -ne $f.before){throw 'Blad przywracania'}
  }
  $state.status='restored';WriteJson $state $statePath
  Write-Host 'Przywrocono oryginalne pliki. Zapisy gry pozostawiono bez zmian. Backup zachowano.'
 }
}catch{Write-Error $_;exit 1}
finally{if($lock){$lock.Dispose()}}
