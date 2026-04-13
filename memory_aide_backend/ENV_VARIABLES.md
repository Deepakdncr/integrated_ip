# CareSoul Backend — Environment Variables

Set these in the Render dashboard (or in a local `.env` file for development).

| Variable | Required | Description | Example |
|---|---|---|---|
| `DATABASE_URL` | Yes | PostgreSQL connection string (Supabase or Render Postgres). | `postgresql://postgres.xxxxx:password@aws-0-ap-south-1.pooler.supabase.com:6543/postgres` |
| `SUPABASE_URL` | Yes | Supabase project URL. | `https://ztghcxcvnpiuqfryampc.supabase.co` |
| `SUPABASE_SERVICE_KEY` | Yes | Supabase **service_role** key (not anon key). Needed for Storage uploads. | `eyJhbGciOiJIUzI1NiIs...` |
| `OPENROUTER_API_KEY` | Yes | OpenRouter AI API key for prescription OCR. | `sk-or-v1-...` |
| `MAIL_USERNAME` | Yes | Gmail address used to send OTP emails. | `caresoul.app@gmail.com` |
| `MAIL_PASSWORD` | Yes | Gmail **App Password** (not account password). | `abcd efgh ijkl mnop` |
| `MAIL_FROM` | Yes | "From" address on outgoing emails (usually same as MAIL_USERNAME). | `caresoul.app@gmail.com` |
| `SECRET_KEY` | Yes | JWT signing secret. Generate a random string for production. | `my-super-secret-key-change-me` |
| `BASE_URL` | Optional | Public backend URL. Used only for legacy file_url entries that are relative paths. | `https://caresoul-backend.onrender.com` |
| `PORT` | Auto | Server listen port. Render sets this automatically — do not set manually. | `8000` |

## Notes
- SMTP is hardcoded to `smtp.gmail.com:587` (STARTTLS).
- `SUPABASE_SERVICE_KEY` is different from `SUPABASE_ANON_KEY`. The service key
  has full storage write access. Find it in Supabase Dashboard → Settings → API → service_role.
- All uploaded files (photos, voices, music, prescriptions) are stored in
  Supabase Storage bucket `caresoul-files`.
