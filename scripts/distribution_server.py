import http.server
import socketserver
import os
import sys
import json
from datetime import datetime

PORT = 8088
DIST_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'dist'))
LOG_FILE = os.path.join(DIST_DIR, 'received_phone_logs.log')
VERSION_FILE = os.path.join(DIST_DIR, 'version.json')

class DiagnosticAndDistributionHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIST_DIR, **kwargs)

    def do_GET(self):
        if self.path == '/api/version':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            if os.path.exists(VERSION_FILE):
                with open(VERSION_FILE, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                default_version = {
                    "versionCode": 3,
                    "versionName": "1.2.0",
                    "apkUrl": f"http://192.168.3.62:{PORT}/b-cam-arm64.apk",
                    "releaseNotes": "Splash screen oficial, IA com Bounding Boxes, Firebase Push com Deeplink e In-App Auto-Update.",
                    "fileSizeBytes": os.path.getsize(os.path.join(DIST_DIR, 'b-cam-arm64.apk')) if os.path.exists(os.path.join(DIST_DIR, 'b-cam-arm64.apk')) else 0,
                    "releaseDate": datetime.now().isoformat()
                }
                self.wfile.write(json.dumps(default_version).encode('utf-8'))
        elif self.path == '/api/status':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'{"status":"online","server":"b-cam distribution and telemetry"}')
        else:
            super().do_GET()

    def do_POST(self):
        if self.path == '/api/logs':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length).decode('utf-8', errors='replace')
            
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            client_ip = self.client_address[0]
            
            with open(LOG_FILE, 'a', encoding='utf-8') as f:
                f.write(f"\n\n==================== LOGS RECEBIDOS DE {client_ip} EM {timestamp} ====================\n")
                f.write(post_data)
                f.write("\n===============================================================================\n")
            
            print(f"[{timestamp}] Recebidos {len(post_data)} bytes de log de {client_ip}")
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(b'{"status":"ok","message":"Logs recebidos com sucesso"}')
        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

if __name__ == '__main__':
    os.chdir(DIST_DIR)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), DiagnosticAndDistributionHandler) as httpd:
        print(f"Servidor de Distribuição & Coleta de Logs b-cam ativo em http://0.0.0.0:{PORT}")
        print(f"Diretório servido: {DIST_DIR}")
        print(f"Arquivo de logs coletados: {LOG_FILE}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nEncerrando servidor...")
