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
# Запускать один раз. Сертификат живёт в связке ключей «Вход».
#
set -euo pipefail

CERT_NAME="Echo Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

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

openssl pkcs12 -export -out "$WORK/cert.p12" \
  -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -name "$CERT_NAME" -passout pass: 2>/dev/null

echo "▶ Импортирую в связку ключей «Вход»…"
# -A разрешает доступ к ключу без отдельного запроса при каждой подписи.
security import "$WORK/cert.p12" -k "$KEYCHAIN" -P "" -T /usr/bin/codesign -A

echo "▶ Помечаю сертификат доверенным для подписи кода…"
security add-trusted-cert -d -r trustAsRoot -p codeSign -k "$KEYCHAIN" "$WORK/cert.pem" \
  || echo "  (не удалось пометить автоматически — подпись всё равно будет работать)"

echo ""
echo "✓ Готово. Теперь scripts/make-dmg.sh подпишет сборку этим сертификатом."
echo "  Доступы, выданные подписанной сборке, переживут следующие обновления."
echo "  Первая подписанная версия — исключение: доступы к ней придётся выдать заново."
