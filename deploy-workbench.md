# Deploy Workbench Skill

Deploy the 端外买断工作台 project to the production server (阿里云 ECS).

## Overview

This skill automates the full deployment pipeline:
1. Pre-deployment checks (git status, uncommitted changes)
2. Git sync to server
3. Frontend build (Vite)
4. Upload frontend dist to server
5. Sync backend code to server
6. Install dependencies & compile backend (TypeScript)
7. Run Prisma migrations if schema changed
8. Restart PM2 process
9. Verify deployment

## Server Configuration

- **Server IP**: `8.136.157.93`
- **Port**: `8080` (due to ICP备案 requirement)
- **SSH Key**: `~/Downloads/alang-key.pem`
- **PM2 Process**: `alang-server` (Node.js on localhost:3001)
- **Nginx Root**: `/var/www/Ad-Performance-Analysis/client/dist`
- **API Proxy**: `/api/` → `http://localhost:3001`
- **Project Path on Server**: `/var/www/Ad-Performance-Analysis`
- **Database**: SQLite at `/var/www/Ad-Performance-Analysis/server/prisma/dev.db`

## Deployment Steps

Execute these steps in order. Stop and report if any step fails.

### 1. Pre-deployment Check

Run from local project root (`/Users/xusulei/端外买断工作台/`):

```bash
git -C /Users/xusulei/端外买断工作台 status
git -C /Users/xusulei/端外买断工作台 log --oneline -5
```

- Ensure working tree is clean (or commit/push changes first).
- Note the latest local commit hash to compare with server later.

### 2. Sync Git to Server

Instead of `git pull` (which may fail with merge conflicts), use `git fetch && git reset --hard`:

```bash
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "cd /var/www/Ad-Performance-Analysis && git fetch origin && git reset --hard origin/main"
```

Verify server is now at the same commit:
```bash
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "cd /var/www/Ad-Performance-Analysis && git log --oneline -1"
```

### 3. Build Frontend Locally

```bash
cd /Users/xusulei/端外买断工作台/client && ./node_modules/.bin/vite build 2>&1
```

After successful build, remove source maps to reduce upload size:
```bash
rm -f /Users/xusulei/端外买断工作台/client/dist/assets/*.map
```

### 4. Upload Frontend Dist

Clear old dist and upload new one:

```bash
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "rm -rf /var/www/Ad-Performance-Analysis/client/dist && mkdir -p /var/www/Ad-Performance-Analysis/client"
scp -i ~/Downloads/alang-key.pem -r /Users/xusulei/端外买断工作台/client/dist root@8.136.157.93:/var/www/Ad-Performance-Analysis/client/
```

### 5. Sync Backend

The backend source is already synced via git in Step 2. However, if there are uncommitted local changes to backend files that were NOT pushed, also scp those specific files:

```bash
# Only needed if there are uncommitted backend changes
# scp -i ~/Downloads/alang-key.pem server/src/routes/*.ts root@8.136.157.93:/var/www/Ad-Performance-Analysis/server/src/routes/
```

### 6. Install Dependencies & Compile

On the server:

```bash
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "cd /var/www/Ad-Performance-Analysis/server && npm install && npx tsc"
```

### 7. Run Prisma Migrations (if needed)

If `prisma/schema.prisma` changed in this deploy:

```bash
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "cd /var/www/Ad-Performance-Analysis/server && npx prisma migrate deploy"
```

If only client generation is needed (no schema change):
```bash
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "cd /var/www/Ad-Performance-Analysis/server && npx prisma generate"
```

### 8. Restart PM2

```bash
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "pm2 restart alang-server && pm2 flush alang-server"
```

Wait 3 seconds for the process to fully start.

### 9. Verify Deployment

```bash
# Check homepage loads
curl -s http://8.136.157.93:8080/ | head -5

# Check API is responsive
curl -s "http://8.136.157.93:8080/api/v1/plans/top5?month=$(date +%Y-%m)" | head -c 200

# Check PM2 status
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "pm2 status alang-server"
```

All checks should return HTTP 200 and valid JSON/HTML.

## Quick Deploy (when only frontend changed)

If only frontend code changed (no backend/api changes), skip steps 2, 5, 6, 7:

```bash
cd /Users/xusulei/端外买断工作台/client && ./node_modules/.bin/vite build
rm -f dist/assets/*.map
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "rm -rf /var/www/Ad-Performance-Analysis/client/dist && mkdir -p /var/www/Ad-Performance-Analysis/client"
scp -i ~/Downloads/alang-key.pem -r dist root@8.136.157.93:/var/www/Ad-Performance-Analysis/client/
curl -s http://8.136.157.93:8080/ | head -3
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `git pull` fails on server | Use `git fetch && git reset --hard origin/main` instead |
| `npx tsc` fails | Check server Node.js version (`node -v`), should be 18+. Run `npm install` first. |
| PM2 restart fails | Check logs: `pm2 logs alang-server --lines 50`. Common causes: port 3001 in use, missing env vars, DB lock. |
| API returns 502 | Nginx proxy error. Check PM2 process is running: `pm2 status`. Check backend on port 3001: `curl localhost:3001/api/v1/overview/daily` |
| CSS/JS 404 after deploy | Nginx root path mismatch. Verify `/var/www/Ad-Performance-Analysis/client/dist` exists and Nginx config points there. |
| Database locked (SQLite) | Stop PM2, run migration manually, restart: `pm2 stop alang-server && npx prisma migrate deploy && pm2 start alang-server` |
| Large dist upload slow | Remove `.map` files before scp. Consider `rsync` instead of `scp -r` for incremental updates. |

## Rollback

If deployment breaks, quickly rollback to previous version:

```bash
# On server
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "cd /var/www/Ad-Performance-Analysis && git log --oneline -5"
# Note the previous commit hash, then:
ssh -i ~/Downloads/alang-key.pem root@8.136.157.93 "cd /var/www/Ad-Performance-Analysis && git reset --hard <PREV_COMMIT_HASH> && cd server && npx tsc && pm2 restart alang-server"
```

## Key Files & Paths Reference

| Local Path | Server Path | Description |
|------------|-------------|-------------|
| `client/dist/` | `/var/www/Ad-Performance-Analysis/client/dist/` | Frontend build output |
| `server/src/` | `/var/www/Ad-Performance-Analysis/server/src/` | Backend source (via git) |
| `server/prisma/schema.prisma` | Same | Database schema |
| `server/prisma/dev.db` | Same | SQLite database file |
