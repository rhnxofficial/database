#!/bin/bash

echo "🚀 Install Nginx Domain Manager..."

apt update -y
apt install nginx curl certbot python3-certbot-nginx -y

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

# hapus default biar gak bentrok
rm -f /etc/nginx/sites-enabled/default

# buat command manager
cat > /usr/local/bin/nginx-manager <<'EOF'
#!/bin/bash

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

function reload_nginx() {
    nginx -t && systemctl reload nginx
}

function tambah_domain() {
    read -p "Masukkan domain: " domain
    read -p "Masukkan IP backend (contoh: 45.137.70.24): " ip
    read -p "Masukkan port backend (contoh: 8003): " port

    read -p "Pakai www juga? (y/n): " pakaiwww

    if [[ $pakaiwww == "y" ]]; then
        SERVER_NAME="$domain www.$domain"
        SSL_DOMAIN="-d $domain -d www.$domain"
    else
        SERVER_NAME="$domain"
        SSL_DOMAIN="-d $domain"
    fi

    config="$NGINX_AVAILABLE/$domain"

    cat > $config <<EOL
server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        proxy_pass http://$ip:$port;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;

        client_max_body_size 50M;
    }
}
EOL

    ln -s $config $NGINX_ENABLED/ 2>/dev/null

    echo "✅ Domain ditambahkan"
    reload_nginx

    read -p "Pasang SSL Let's Encrypt? (y/n): " ssl
    if [[ $ssl == "y" ]]; then
        certbot --nginx $SSL_DOMAIN
    fi
}

function list_domain() {
    echo "=== DOMAIN AKTIF ==="
    ls $NGINX_ENABLED
}

function hapus_domain() {
    read -p "Domain yang dihapus: " domain
    rm -f $NGINX_ENABLED/$domain
    rm -f $NGINX_AVAILABLE/$domain
    reload_nginx
    echo "🗑️ Domain dihapus"
}

function kelola_domain() {
    read -p "Masukkan domain: " domain

    echo "a. Pasang SSL"
    echo "b. Edit config manual"
    echo "c. Kembali"
    read -p "Pilih: " pilih

    case $pilih in
        a) certbot --nginx -d $domain ;;
        b) nano $NGINX_AVAILABLE/$domain; reload_nginx ;;
    esac
}

while true; do
    clear
    echo "==== Nginx Domain Manager ===="
    echo "1. Tambah domain"
    echo "2. List domain"
    echo "3. Kelola domain"
    echo "4. Hapus domain"
    echo "5. Keluar"
    echo "=============================="

    read -p "Pilih menu: " menu

    case $menu in
        1) tambah_domain ;;
        2) list_domain; read -p "Enter..." ;;
        3) kelola_domain ;;
        4) hapus_domain ;;
        5) exit ;;
    esac
done
EOF

chmod +x /usr/local/bin/nginx-manager

echo "✅ Install selesai!"
echo "👉 Jalankan: nginx-manager"
