#!/bin/bash
#
# setup-signing.sh — создаёт самоподписанный сертификат для подписи Echo.
#
# Зачем: macOS запоминает выданные приложению доступы (Accessibility, Input
# Monitoring) по его подписи. У ad-hoc сборки подписи как таковой нет —
# система опознаёт её по хешу кода, а он меняется с каждой сборкой, поэтому
# после каждого обновления доступы приходится выдавать заново.
#
# Один и тот же сертификат для всех сборок даёт стабильную подпись — и доступы
# переживают обновление. Нотаризацию это не заменяет: Gatekeeper при первой
# установке по-прежнему будет ругаться.
#
# Запускать один раз, БЕЗ sudo: связка ключей у каждого пользователя своя,
# под root сертификат уедет в чужую и сборка его не найдёт.
#
# Скрипт спросит пароль от связки ключей «Вход» — это твой пароль входа в
# систему. Права администратора не нужны, системные диалоги не открываются.
#
set -euo pipefail

CERT_NAME="Echo Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "✗ Не запускай через sudo — сертификат попадёт в связку root, а не в твою."
  echo "  Повтори без sudo:  ./scripts/setup-signing.sh"
  exit 1
fi

if security find-certificate -c "$CERT_NAME" >/dev/null 2>&1; then
  echo "✓ Сертификат «$CERT_NAME» уже есть — ничего делать не нужно."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▶ Генерирую сертификат для подписи кода…"
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
  -subj "/CN=$CERT_NAME/O=Echo/C=RU" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null

# Пароль контейнера обязательно непустой: с пустым `security import` падает
# на проверке MAC («wrong password?»). Контейнер временный и тут же удаляется.
P12_PASS="$(openssl rand -hex 16)"
openssl pkcs12 -export -out "$WORK/cert.p12" \
  -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -name "$CERT_NAME" -passout "pass:$P12_PASS" 2>/dev/null

echo "▶ Импортирую в связку ключей «Вход»…"
security import "$WORK/cert.p12" -k "$KEYCHAIN" -P "$P12_PASS" -T /usr/bin/codesign -A

# Без этого шага codesign падает с errSecInternalComponent: ключ импортирован,
# но не разрешён к использованию инструментами подписи.
echo "▶ Разрешаю codesign пользоваться ключом."
echo "  Дальше security спросит пароль от связки ключей «Вход» — это пароль твоей учётной записи."
security set-key-partition-list -S apple-tool:,apple:,codesign: -s "$KEYCHAIN" >/dev/null

echo ""
echo "✓ Готово. Теперь scripts/make-dmg.sh подпишет сборку этим сертификатом."
echo "  Доступы, выданные подписанной сборке, переживут следующие обновления."
echo "  Первая подписанная версия — исключение: доступы к ней придётся выдать заново."
