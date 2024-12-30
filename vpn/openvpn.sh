#!/bin/bash

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
  echo "Пожалуйста, запустите скрипт с правами root."
  exit 1
fi

# Функция установки необходимых пакетов
install_packages() {
  echo "[*] Установка необходимых пакетов..."
  apt-get update
  apt-get install -y openvpn iptables-persistent curl dnsmasq
}

# Включение перенаправления IP
enable_ip_forwarding() {
  echo "[*] Включение IP переадресации..."
  sysctl -w net.ipv4.ip_forward=1
  sed -i '/^#net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf
}

# Настройка iptables для NAT
setup_iptables() {
  echo "[*] Настройка iptables для NAT..."
  read -p "Введите имя сетевого интерфейса для выхода в интернет (например, eth0): " external_interface
  iptables -t nat -A POSTROUTING -o "$external_interface" -j MASQUERADE
  iptables -A FORWARD -i tun0 -o "$external_interface" -j ACCEPT
  iptables -A FORWARD -i "$external_interface" -o tun0 -m state --state RELATED,ESTABLISHED -j ACCEPT
  echo "[*] Сохранение iptables правил..."
  iptables-save > /etc/iptables/rules.v4
}

# Проверка OpenVPN конфигурации
check_openvpn_config() {
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
}

# Настройка DNS с помощью dnsmasq
setup_dnsmasq() {
  echo "[*] Настройка DNS через dnsmasq..."
  local_ip="192.168.1.1"
  cat <<EOF > /etc/dnsmasq.conf
dhcp-authoritative
domain=local
listen-address=127.0.0.1,$local_ip
dhcp-range=${local_ip%.*}.2,${local_ip%.*}.254,255.255.255.0,12h
server=8.8.8.8
server=8.8.4.4
cache-size=10000
EOF

  systemctl restart dnsmasq
  systemctl enable dnsmasq
}

# Запуск OpenVPN
start_openvpn() {
  echo "[*] Запуск OpenVPN клиента..."
  systemctl enable openvpn@client
  systemctl start openvpn@client
}

# Проверка интернет-соединения через OpenVPN
check_internet_connection() {
  echo "[*] Проверка интернет-соединения через OpenVPN..."
  sleep 5
  if curl -s --head --request GET http://google.com | grep "200 OK" > /dev/null; then
    echo "[*] Интернет через OpenVPN работает корректно."
  else
    echo "[!] Интернет через OpenVPN недоступен. Проверьте конфигурацию OpenVPN и сетевые настройки."
  fi
}

# Основной процесс
main() {
  install_packages
  enable_ip_forwarding
  setup_iptables
  check_openvpn_config
  setup_dnsmasq
  start_openvpn
  check_internet_connection
  echo "[*] Настройка завершена!"
}

main
