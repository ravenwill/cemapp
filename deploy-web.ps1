# Publica o CEMAPP web no GitHub Pages: .\deploy-web.ps1
$env:Path += ';C:\Program Files\GitHub CLI'
Set-Location $PSScriptRoot
$ver = Get-Date -Format 'yyyyMMddHHmmss'
Set-Content -Path web\version.json -Value "{`"version`":`"$ver`"}" -Encoding ASCII
C:\dev\flutter\bin\flutter.bat build web --release --no-tree-shake-icons --base-href /cemapp/
Set-Location build\web
New-Item .nojekyll -ItemType File -Force | Out-Null
git add -A
git commit -m "Atualiza CEMAPP"
$env:GIT_TERMINAL_PROMPT='0'
git push

