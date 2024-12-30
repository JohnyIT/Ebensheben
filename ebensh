#!/bin/bash

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт с правами root."
  exit 1
fi

# Установка необходимых пакетов
echo "[*] Установка необходимых пакетов..."
apt-get update
apt-get install -y openvpn iptables-persistent curl

# Включение перенаправления IP
echo "[*] Включение IP переадресации..."
sysctl -w net.ipv4.ip_forward=1
sed -i '/^#net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf

# Настройка iptables для NAT
echo "[*] Настройка iptables для NAT..."
read -p "Введите имя сетевого интерфейса для выхода в интернет (например, eth0): " external_interface
iptables -t nat -A POSTROUTING -o "$external_interface" -j MASQUERADE
iptables -A FORWARD -i tun0 -o "$external_interface" -j ACCEPT
iptables -A FORWARD -i "$external_interface" -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Сохранение iptables правил
echo "[*] Сохранение iptables правил..."
iptables-save > /etc/iptables/rules.v4

# Проверка наличия OpenVPN конфигурации
config_dir="/etc/openvpn"
config_file="$config_dir/client.conf"

if [ ! -d "$config_dir" ]; then
  echo "[!] Директория $config_dir не существует. Убедитесь, что вы установили OpenVPN сервер или клиент конфигурацию."
  exit 1
fi

if [ ! -f "$config_file" ]; then
  echo "[!] Конфигурационный файл $config_file не найден. Поместите ваш OpenVPN клиентский конфиг в $config_dir."
  exit 1
fi

# Запуск OpenVPN
echo "[*] Запуск OpenVPN клиента..."
systemctl enable openvpn@client
systemctl start openvpn@client

# Проверка соединения
echo "[*] Проверка интернет-соединения через OpenVPN..."
sleep 5
if curl -s --head --request GET http://google.com | grep "200 OK" > /dev/null; then
  echo "[*] Интернет через OpenVPN работает корректно."
else
  echo "[!] Интернет через OpenVPN недоступен. Проверьте конфигурацию OpenVPN и сетевые настройки."
fi

echo "[*] Настройка завершена!"
