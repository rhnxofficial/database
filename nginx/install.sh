#!/bin/bash

# Cara jalanin:
# bash <(curl -s https://raw.githubusercontent.com/rhnxofficial/database/main/nginx/install.sh)

set -e

echo "🚀 Install Nginx Domain Manager..."

if [[ $EUID -ne 0 ]]; then
    echo "❌ Jalankan sebagai root"
    exit 1
fi

apt update -y
apt install nginx curl certbot python3-certbot-nginx nano -y

systemctl enable nginx
systemctl start nginx

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

rm -f /etc/nginx/sites-enabled/default

cat > /usr/local/bin/nginx-manager <<'EOF'
#!/bin/bash

NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

function reload_nginx() {
    echo "🔍 Mengecek config nginx..."

    if nginx -t; then
        systemctl reload nginx
        echo "✅ Nginx berhasil direload"
    else
        echo "❌ Config nginx error!"
        echo "Periksa config lalu coba lagi."
    fi
}

function valid_domain() {
    [[ "$1" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]
}

function tambah_domain() {

    read -p "Masukkan domain: " domain

    if ! valid_domain "$domain"; then
        echo "❌ Domain tidak valid"
        return
    fi

    if [[ -f "$NGINX_AVAILABLE/$domain" ]]; then
        echo "❌ Domain sudah ada"
        return
    fi

    read -p "Masukkan IP backend: " ip

    if ! [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "❌ Format IP tidak valid"
        return
    fi

    read -p "Masukkan port backend: " port

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "❌ Port tidak valid"
        return
    fi

    read -p "Pakai www juga? (y/n): " pakaiwww

    if [[ $pakaiwww == "y" ]]; then
        SERVER_NAME="$domain www.$domain"
        SSL_DOMAIN="-d $domain -d www.$domain"
    else
        SERVER_NAME="$domain"
        SSL_DOMAIN="-d $domain"
    fi

    config="$NGINX_AVAILABLE/$domain"

    cat > "$config" <<EOL
server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        proxy_pass http://$ip:$port;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        client_max_body_size 50M;
    }
}
EOL

    ln -sf "$config" "$NGINX_ENABLED/$domain"

    echo "🔄 Reload nginx..."
    reload_nginx

    echo ""
    echo "⚠️ Pastikan domain sudah mengarah ke VPS"
    read -p "Pasang SSL Let's Encrypt? (y/n): " ssl

    if [[ $ssl == "y" ]]; then
        certbot --nginx $SSL_DOMAIN
    fi
}

function list_domain() {
    echo ""
    echo "===== DOMAIN AKTIF ====="

    if [[ -z $(ls -A "$NGINX_ENABLED") ]]; then
        echo "Belum ada domain"
    else
        for file in "$NGINX_ENABLED"/*; do
            basename "$file"
        done
    fi

    echo "========================"
}

function hapus_domain() {

    read -p "Domain yang dihapus: " domain

    if [[ ! -f "$NGINX_AVAILABLE/$domain" ]]; then
        echo "❌ Domain tidak ditemukan"
        return
    fi

    read -p "Hapus SSL juga? (y/n): " delssl

    if [[ $delssl == "y" ]]; then
        certbot delete --cert-name "$domain"
    fi

    rm -f "$NGINX_ENABLED/$domain"
    rm -f "$NGINX_AVAILABLE/$domain"

    reload_nginx

    echo "🗑️ Domain dihapus"
}

function kelola_domain() {

    read -p "Masukkan domain: " domain

    if [[ ! -f "$NGINX_AVAILABLE/$domain" ]]; then
        echo "❌ Domain tidak ditemukan"
        return
    fi

    echo ""
    echo "a. Pasang SSL"
    echo "b. Edit config manual"
    echo "c. Restart nginx"
    echo "d. Kembali"

    read -p "Pilih: " pilih

    case $pilih in
        a)
            read -p "Pakai www juga? (y/n): " pakaiwww

            if [[ $pakaiwww == "y" ]]; then
                certbot --nginx -d "$domain" -d "www.$domain"
            else
                certbot --nginx -d "$domain"
            fi
        ;;
        b)
            nano "$NGINX_AVAILABLE/$domain"
            reload_nginx
        ;;
        c)
            systemctl restart nginx
            echo "✅ Nginx direstart"
        ;;
    esac
}

while true; do
    clear

    echo "==============================="
    echo "     NGINX DOMAIN MANAGER"
    echo "==============================="
    echo "1. Tambah domain"
    echo "2. List domain"
    echo "3. Kelola domain"
    echo "4. Hapus domain"
    echo "5. Keluar"
    echo "==============================="

    read -p "Pilih menu: " menu

    case $menu in
        1)
            tambah_domain
            read -p "Tekan enter..."
        ;;
        2)
            list_domain
            read -p "Tekan enter..."
        ;;
        3)
            kelola_domain
            read -p "Tekan enter..."
        ;;
        4)
            hapus_domain
            read -p "Tekan enter..."
        ;;
        5)
            exit
        ;;
        *)
            echo "❌ Menu tidak valid"
            sleep 1
        ;;
    esac
done
EOF

chmod +x /usr/local/bin/nginx-manager

echo ""
echo "✅ Install selesai!"
echo "👉 Jalankan: nginx-manager"
