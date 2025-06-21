# Скрипт для создания keystore файла
Write-Host "Поиск Java и создание keystore..." -ForegroundColor Green

# Попытка найти Java в различных местах
$javaPaths = @(
    "java",
    "C:\Program Files\Java\jdk*\bin\keytool.exe",
    "C:\Program Files\Eclipse Adoptium\jdk*\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jre\bin\keytool.exe",
    "$env:LOCALAPPDATA\Android\Sdk\jbr\bin\keytool.exe"
)

$keytoolPath = $null
foreach ($path in $javaPaths) {
    try {
        $found = Get-Command $path -ErrorAction SilentlyContinue
        if ($found) {
            $keytoolPath = $found.Source
            Write-Host "Найден keytool: $keytoolPath" -ForegroundColor Green
            break
        }
    }
    catch {
        # Игнорируем ошибки
    }
}

if (-not $keytoolPath) {
    Write-Host "keytool не найден. Попробуйте следующие варианты:" -ForegroundColor Red
    Write-Host "1. Установите Java JDK" -ForegroundColor Yellow
    Write-Host "2. Установите Android Studio" -ForegroundColor Yellow
    Write-Host "3. Используйте Android Studio для создания подписи" -ForegroundColor Yellow
    exit 1
}

# Создаем keystore
$keystorePath = "android\app\release-key.jks"
Write-Host "Создание keystore: $keystorePath" -ForegroundColor Green

$dname = "CN=Pagan Quotes App, OU=Development, O=Sacral, L=City, S=State, C=US"
$storePass = "1488228"
$keyPass = "1488228"
$alias = "release"

$arguments = @(
    "-genkey",
    "-v",
    "-keystore", $keystorePath,
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "10000",
    "-alias", $alias,
    "-storepass", $storePass,
    "-keypass", $keyPass,
    "-dname", $dname
)

try {
    & $keytoolPath @arguments
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Keystore успешно создан!" -ForegroundColor Green
        Write-Host "Файл: $keystorePath" -ForegroundColor Green
        Write-Host "Пароль: $storePass" -ForegroundColor Green
    } else {
        Write-Host "Ошибка при создании keystore" -ForegroundColor Red
    }
}
catch {
    Write-Host "Ошибка: $_" -ForegroundColor Red
} 