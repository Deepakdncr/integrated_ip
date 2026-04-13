# CareSoul Deployment Checklist

## Already Done
- [x] Supabase project created (caresoul)
- [x] Supabase DB ready
- [x] Supabase Storage bucket created (caresoul-files)
- [x] All credentials saved in notepad

## Step 1 — Push to GitHub
- [ ] git add .
- [ ] git commit -m "production: render + supabase deployment"
- [ ] git push origin main

## Step 2 — Deploy Backend on Render
- [ ] render.com -> New -> Web Service
- [ ] Connect GitHub -> integrated_ip
- [ ] Root directory: memory_aide_backend
- [ ] Build: pip install -r requirements.txt
- [ ] Start: uvicorn main:app --host 0.0.0.0 --port $PORT
- [ ] Add ALL environment variables from notepad:
  - DATABASE_URL -> Supabase PostgreSQL connection string
  - SUPABASE_URL -> https://ztghcxcvnpiuqfryampc.supabase.co
  - SUPABASE_SERVICE_KEY -> Supabase service_role key (Settings -> API)
  - OPENROUTER_API_KEY -> your key
  - MAIL_USERNAME -> your Gmail address
  - MAIL_PASSWORD -> Gmail App Password
  - MAIL_FROM -> same as MAIL_USERNAME
  - SECRET_KEY -> any random string (e.g. generate with: python -c "import secrets; print(secrets.token_hex(32))")
- [ ] Click Deploy
- [ ] Wait for deploy to finish
- [ ] Copy Render URL: https://_______.onrender.com

## Step 3 — Update URLs
- [ ] memory_aide_app/lib/config/api_config.dart -> replace YOUR_RENDER_URL
- [ ] esp32_reminder.ino -> replace YOUR_RENDER_URL
- [ ] git add . && git commit -m "update: production URLs" && git push

## Step 4 — Deploy Flutter Web on Vercel
- [ ] cd memory_aide_app
- [ ] flutter clean && flutter pub get
- [ ] flutter build web --release
- [ ] npm i -g vercel
- [ ] vercel deploy build/web --prod

## Step 5 — Build Android APK
- [ ] flutter build apk --release
- [ ] APK: build/app/outputs/flutter-apk/app-release.apk

## Step 6 — Flash ESP32
- [ ] Open esp32_reminder.ino in Arduino IDE
- [ ] Update WIFI_SSID + WIFI_PASSWORD
- [ ] Update DEVICE_ID (unique per device)
- [ ] Upload to each ESP32

## Step 7 — End-to-End Test
- [ ] Open app -> login -> set reminder 2 mins from now
- [ ] ESP32 Serial Monitor -> confirm schedule received
- [ ] Wait 2 mins -> confirm audio plays
- [ ] Press SOS button -> confirm app alert
- [ ] Stop SOS from app -> confirm buzzer stops
- [ ] Upload a voice recording -> confirm it saves to Supabase Storage
- [ ] Upload a song -> confirm it saves to Supabase Storage
- [ ] Check Supabase dashboard -> Storage -> caresoul-files -> verify files appear

## Important Notes
- Supabase Storage bucket `caresoul-files` must have public access enabled
  (Dashboard -> Storage -> caresoul-files -> Policies -> allow public SELECT)
- Free Render instances sleep after ~15min idle. First request takes 30-60s.
- SECRET_KEY must be a strong random string in production.
- CORS is currently allow_origins=["*"]. Lock down to your Vercel domain after testing.
