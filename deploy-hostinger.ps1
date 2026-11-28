# Gera o CEMAPP web para a Hostinger (servido na raiz do dominio): .\deploy-hostinger.ps1
# Saida: build\web (conteudo do public_html) e zips\cemapp-hostinger.zip
Set-Location $PSScriptRoot
$ver = Get-Date -Format 'yyyyMMddHHmmss'
Set-Content -Path web\version.json -Value "{`"version`":`"$ver`"}" -Encoding ASCII
C:\dev\flutter\bin\flutter.bat build web --release --no-tree-shake-icons --base-href /
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

New-Item -ItemType Directory -Force zips | Out-Null
$zip = 'zips\cemapp-hostinger.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
# -Force inclui arquivos ocultos como .htaccess
Compress-Archive -Path (Get-ChildItem build\web -Force).FullName -DestinationPath $zip
Write-Host "Pronto: envie o conteudo de build\web (ou extraia $zip) em public_html."
