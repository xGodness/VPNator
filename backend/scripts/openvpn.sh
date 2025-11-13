# if [ "$(id -u)" -eq 0 ]; then echo "Этот скрипт нельзя запускать от root!"; exit 1; fi

apt-get update
apt-get install -y --no-install-recommends openvpn openssl ca-certificates iptables wget iptables-persistent
# VPNATOR-STATUS-REPORT Установлены необходимые пакеты

mkdir -p /etc/openvpn/server/easy-rsa
wget -qO- https://github.com/OpenVPN/easy-rsa/releases/download/v3.2.4/EasyRSA-3.2.4.tgz | tar xz -C /etc/openvpn/server/easy-rsa --strip-components 1
chown -R root:root /etc/openvpn/server/easy-rsa
# VPNATOR-STATUS-REPORT EasyRSA скачан и распакован

cd /etc/openvpn/server/easy-rsa && ./easyrsa --batch init-pki
cd /etc/openvpn/server/easy-rsa && ./easyrsa --batch build-ca nopass
cd /etc/openvpn/server/easy-rsa && ./easyrsa gen-tls-crypt-key
# VPNATOR-STATUS-REPORT Инициализирован PKI, сгенерирован CA и tls-crypt key

echo "-----BEGIN DH PARAMETERS-----" > /etc/openvpn/server/dh.pem
echo "MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz" >> /etc/openvpn/server/dh.pem
echo "+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a" >> /etc/openvpn/server/dh.pem
echo "87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7" >> /etc/openvpn/server/dh.pem
echo "YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi" >> /etc/openvpn/server/dh.pem
echo "7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD" >> /etc/openvpn/server/dh.pem
echo "ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==" >> /etc/openvpn/server/dh.pem
echo "-----END DH PARAMETERS-----" >> /etc/openvpn/server/dh.pem

ln -sf /etc/openvpn/server/dh.pem /etc/openvpn/server/easy-rsa/pki/dh.pem
# VPNATOR-STATUS-REPORT DH параметры сгенерированы и симлинк создан

cd /etc/openvpn/server/easy-rsa && ./easyrsa --batch --days=3650 build-server-full server nopass
cd /etc/openvpn/server/easy-rsa && ./easyrsa --batch --days=3650 gen-crl
# VPNATOR-STATUS-REPORT Серверный сертификат и CRL сгенерированы

cp /etc/openvpn/server/easy-rsa/pki/ca.crt /etc/openvpn/server/
cp /etc/openvpn/server/easy-rsa/pki/private/ca.key /etc/openvpn/server/
cp /etc/openvpn/server/easy-rsa/pki/issued/server.crt /etc/openvpn/server/
cp /etc/openvpn/server/easy-rsa/pki/private/server.key /etc/openvpn/server/
cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/
cp /etc/openvpn/server/easy-rsa/pki/private/easyrsa-tls.key /etc/openvpn/server/tc.key
chown nobody:nogroup /etc/openvpn/server/crl.pem
chmod o+x /etc/openvpn/server/
# VPNATOR-STATUS-REPORT Ключи и сертификаты скопированы, права выставлены

echo "port 1194" > /etc/openvpn/server/server.conf
echo "proto udp" >> /etc/openvpn/server/server.conf
echo "dev tun" >> /etc/openvpn/server/server.conf
echo "ca ca.crt" >> /etc/openvpn/server/server.conf
echo "cert server.crt" >> /etc/openvpn/server/server.conf
echo "key server.key" >> /etc/openvpn/server/server.conf
echo "dh dh.pem" >> /etc/openvpn/server/server.conf
echo "auth SHA512" >> /etc/openvpn/server/server.conf
echo "tls-crypt tc.key" >> /etc/openvpn/server/server.conf
echo "topology subnet" >> /etc/openvpn/server/server.conf
echo "server 10.8.0.0 255.255.255.0" >> /etc/openvpn/server/server.conf
echo "push \"redirect-gateway def1 bypass-dhcp\"" >> /etc/openvpn/server/server.conf
echo "push \"dhcp-option DNS 8.8.8.8\"" >> /etc/openvpn/server/server.conf
echo "push \"block-outside-dns\"" >> /etc/openvpn/server/server.conf
echo "ifconfig-pool-persist ipp.txt" >> /etc/openvpn/server/server.conf
echo "keepalive 10 120" >> /etc/openvpn/server/server.conf
echo "user nobody" >> /etc/openvpn/server/server.conf
echo "group nogroup" >> /etc/openvpn/server/server.conf
echo "persist-key" >> /etc/openvpn/server/server.conf
echo "persist-tun" >> /etc/openvpn/server/server.conf
echo "verb 3" >> /etc/openvpn/server/server.conf
echo "crl-verify crl.pem" >> /etc/openvpn/server/server.conf
echo "explicit-exit-notify" >> /etc/openvpn/server/server.conf
# VPNATOR-STATUS-REPORT Конфиг сервера создан

echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-openvpn-forward.conf
echo 1 > /proc/sys/net/ipv4/ip_forward
# VPNATOR-STATUS-REPORT Включён IP forwarding

iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j MASQUERADE
iptables -I INPUT -p udp --dport 1194 -j ACCEPT
iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
netfilter-persistent save
# VPNATOR-STATUS-REPORT Настроен и сохранён NAT через iptables

systemctl enable --now openvpn-server@server.service
# VPNATOR-STATUS-REPORT OpenVPN сервер запущен и добавлен в автозагрузку

cd /etc/openvpn/server/easy-rsa && ./easyrsa --batch --days=3650 build-client-full client nopass
# VPNATOR-STATUS-REPORT Сгенерирован клиентский сертификат

curl -s4 ifconfig.me > /etc/openvpn/server/server_ip.txt
# VPNATOR-STATUS-REPORT Внешний IPv4 сервера определён

echo "client" > /etc/openvpn/server/client-common.txt
echo "dev tun" >> /etc/openvpn/server/client-common.txt
echo "proto udp" >> /etc/openvpn/server/client-common.txt
echo "remote $(cat /etc/openvpn/server/server_ip.txt) 1194" >> /etc/openvpn/server/client-common.txt
echo "resolv-retry infinite" >> /etc/openvpn/server/client-common.txt
echo "nobind" >> /etc/openvpn/server/client-common.txt
echo "persist-key" >> /etc/openvpn/server/client-common.txt
echo "persist-tun" >> /etc/openvpn/server/client-common.txt
echo "remote-cert-tls server" >> /etc/openvpn/server/client-common.txt
echo "auth SHA512" >> /etc/openvpn/server/client-common.txt
echo "ignore-unknown-option block-outside-dns" >> /etc/openvpn/server/client-common.txt
echo "verb 3" >> /etc/openvpn/server/client-common.txt
echo "<tls-crypt>" >> /etc/openvpn/server/client-common.txt
cat /etc/openvpn/server/tc.key >> /etc/openvpn/server/client-common.txt
echo "</tls-crypt>" >> /etc/openvpn/server/client-common.txt
# VPNATOR-STATUS-REPORT Создан шаблон client-common.txt

cp /etc/openvpn/server/client-common.txt ~/client.ovpn
echo "<ca>" >> ~/client.ovpn
cat /etc/openvpn/server/ca.crt >> ~/client.ovpn
echo "</ca>" >> ~/client.ovpn
echo "<cert>" >> ~/client.ovpn
cat /etc/openvpn/server/easy-rsa/pki/issued/client.crt >> ~/client.ovpn
echo "</cert>" >> ~/client.ovpn
echo "<key>" >> ~/client.ovpn
cat /etc/openvpn/server/easy-rsa/pki/private/client.key >> ~/client.ovpn
echo "</key>" >> ~/client.ovpn
# VPNATOR-STATUS-REPORT Итоговый клиентский конфиг client.ovpn собран

cat ~/client.ovpn # VPNATOR-SAVE-OUTPUT
