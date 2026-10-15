# GodarChat (LibreChat) برای همه‌ی tenantها

یک LibreChat مشترک با `MULTI_TENANT_MODE=host` روی `https://{slug}.chat.godarai.ir`. LibreChat tenant را از هدر `Host` تشخیص می‌دهد، پس برای tenant جدید هیچ چیزی در کوبر ساخته نمی‌شود. control-plane خودش tenantها را به LibreChat معرفی می‌کند (`internal/chatprovisioning`، مستند: `docs/chat-tenant-provisioning.md` در ریپوی Shahrah).

```
Browser ──https──> ingress-nginx
  {slug}.godarai.ir        /v1, /oidc, /.well-known/openid-configuration -> control-plane
                           /                                              -> tenant-admin
  {slug}.chat.godarai.ir   /  (cert *.chat.godarai.ir)                    -> librechat:3080  (3..12 pod, HPA)

control-plane ──PUT /tenants/{id}──> librechat:3081   (فقط control-plane؛ بدون Ingress)

librechat ──> mongodb (replica set، ۳ عضو)   helm/mongodb
          ──> librechat-redis (standalone)    apps/librechat-redis.yaml
          ──> minio:9000 (bucket godarai-chat) helm/shahrah privateFiles
          ──> https://{slug}.godarai.ir        OIDC و gateway
```

## چه چیزی کجاست

| مورد | مسیر |
|---|---|
| Deployment، Service، Ingress، HPA، PDB، NetworkPolicy | `librechat:` در `helm/shahrah/values*.yaml` (همان الگوی بقیه‌ی workloadها) |
| `librechat.yaml` (مشترک بین tenantها) | `librechat.config` در همان values؛ `{slug}` در `baseURL` با slug درخواست جایگزین می‌شود |
| ساخت bucket و کاربر MinIO محدود | `helm/shahrah/templates/librechat.yaml` (Job `librechat-bucket-init`) |
| MongoDB | `helm/mongodb` + `apps/mongodb.yaml` |
| Redis | `apps/librechat-redis.yaml` |
| گواهی `*.chat.godarai.ir` | `platform/godarai-tls/chat-wildcard-certificate.yaml` |
| env فعال‌سازی provisioning | `controlPlane.env.CHAT_*` در `values.production.yaml` |

## Secretها (خارج از Git، namespace: `shahrah-production`)

```bash
NS=shahrah-production
PW_MONGO_ROOT=$(openssl rand -hex 24); PW_MONGO_APP=$(openssl rand -hex 24)
PW_REDIS=$(openssl rand -hex 24); PROV_TOKEN=$(openssl rand -hex 32)
S3_KEY=librechat; S3_SECRET=$(openssl rand -hex 24)

kubectl -n $NS create secret generic mongodb-secret \
  --from-literal=mongodb-root-username=root --from-literal=mongodb-root-password=$PW_MONGO_ROOT \
  --from-literal=librechat-password=$PW_MONGO_APP \
  --from-literal=mongodb-keyfile="$(openssl rand -base64 756)"

kubectl -n $NS create secret generic librechat-redis --from-literal=redis-password=$PW_REDIS

M=mongodb-0.mongodb-headless.$NS.svc.cluster.local:27017,mongodb-1.mongodb-headless.$NS.svc.cluster.local:27017,mongodb-2.mongodb-headless.$NS.svc.cluster.local:27017
kubectl -n $NS create secret generic librechat-secret \
  --from-literal=CREDS_KEY=$(openssl rand -hex 32) --from-literal=CREDS_IV=$(openssl rand -hex 16) \
  --from-literal=JWT_SECRET=$(openssl rand -hex 32) --from-literal=JWT_REFRESH_SECRET=$(openssl rand -hex 32) \
  --from-literal=OPENID_SESSION_SECRET=$(openssl rand -hex 32) \
  --from-literal=TENANT_PROVISIONING_TOKEN=$PROV_TOKEN \
  --from-literal=MONGO_URI="mongodb://librechat:$PW_MONGO_APP@$M/LibreChat?replicaSet=rs0&authSource=LibreChat" \
  --from-literal=REDIS_URI="redis://:$PW_REDIS@librechat-redis-master:6379" \
  --from-literal=AWS_ACCESS_KEY_ID=$S3_KEY --from-literal=AWS_SECRET_ACCESS_KEY=$S3_SECRET
```

علاوه بر این، کلید `CHAT_PROVISIONING_TOKEN` با **همان مقدار** `PROV_TOKEN` به Secret موجود `shahrah-secret` اضافه شود.

`CREDS_KEY`/`CREDS_IV` هم کلیدهای کاربران و هم secret OIDC همه‌ی tenantها را رمز می‌کنند. گم‌شدنشان یعنی از دست رفتن آن داده‌ها؛ حتماً خارج از کلاستر backup بگیرید و هرگز عوضشان نکنید.

## ترتیب راه‌اندازی

1. DNS: رکورد wildcard `*.chat.godarai.ir` به همان لودبالانسر ingress (Arvan).
2. اجرای دستی workflow `Mirror Quay Images` تا `docker.io/delpak/godar-ai:mirror-mongo-8.0.20` ساخته شود.
3. ایمیج GodarChat ساخته شده است و با tag خالص منتشر می‌شود: `docker.io/delpak/godar-ai:v0.9.0-rc2` (بدون پیشوند `librechat-`؛ workflow فورک آن را با `api-` برای نسخه‌ی API هم push می‌کند). مقدار در `librechat.image.fullTag` پین شده است؛ برای نسخه‌ی جدید فقط همین را عوض کنید.
4. ساخت Secretها (بالا).
5. release نسخه‌ای از control-plane که شامل `internal/chatprovisioning` است (در main هست ولی در `v0.72.0` نیست) و بالا بردن `controlPlane.image.tag`. تا آن موقع `CHAT_*` نادیده گرفته می‌شود.
6. merge: Argo اول mongodb (Job `mongodb-init` بعد از sync، replica set و کاربر برنامه را می‌سازد)، redis، سپس chart اصلی (Job ساخت bucket در wave `-9`) را اعمال می‌کند.
7. با فعال‌شدن provisioning، پاس اول control-plane برای **همه‌ی tenantهای موجود** یک OIDC client `GodarChat` می‌سازد و آن‌ها را در LibreChat ثبت می‌کند. استثناها: سطر `skipped` در `tenant_chat_provisioning` (SQL در مستند Shahrah).

## مقیاس

pod های LibreChat stateless هستند (session، stream و limiter در Redis؛ داده در Mongo؛ فایل در S3). HPA بین ۳ تا ۱۲ replica روی CPU و حافظه؛ PDB با `minAvailable: 2`؛ `maxUnavailable: 0` در rollout. اگر Mongo یا Redis گلوگاه شد، منابعشان را در `helm/mongodb/values.yaml` و `apps/librechat-redis.yaml` بالا ببرید.

## محدودیت‌ها و ریسک‌های شناخته‌شده

- **Redis تک‌نمونه است.** کلاینت LibreChat Sentinel/failover ندارد؛ AOF داده را نگه می‌دارد ولی در قطعی، چت تا برگشت Redis در دسترس نیست.
- **MinIO تک‌نمونه و ۱Gi است** (`privateFiles.minio.persistence`، ساخته‌شده برای فایل‌های support). حجم فایل‌های چت همین‌جا ذخیره می‌شود. `volumeClaimTemplates` استیت‌فول‌ست immutable است؛ PVC را در Longhorn دستی expand کنید، بعد مقدار را در values هم‌خوان کنید. در عمل بهتر است MinIO جدا یا HA بگیرد.
- **اندازه‌ی volumeهای Mongo ۵Gi است** (هر عضو و backup)، چون Longhorn بر اساس حجم درخواستی زمان‌بندی می‌کند و روی هر نود حدود ۸۵ از ۱۰۵ گیگ از قبل رزرو شده است. volume را می‌شود online بزرگ کرد ولی کوچک نه. اگر `volumeClaimTemplates` عوض شد، StatefulSet و PVCها باید دستی حذف و دوباره ساخته شوند.
- **MongoDB:** backup منطقی روزانه روی PVC جدا (۷ نسخه) فقط محافظ خطای انسانی است، نه خرابی دیسک/کلاستر. نسخه‌ی خارج کلاستر لازم است. exporter/alert برای Mongo هنوز نیست.
- **دسترسی pod به issuer** (`https://{slug}.godarai.ir`، discovery و gateway) از آدرس عمومی می‌گذرد (egress به ۴۴۳ آزاد است). rewrite در CoreDNS به ingress-nginx داخلی بهتر است.
- **توکن gateway:** `{{LIBRECHAT_OPENID_ACCESS_TOKEN}}` در حالت host با `OPENID_REUSE_TOKENS` خاموش کار می‌کند فقط اگر توکن login در `user.federatedTokens` در درخواست‌های بعدی هم موجود باشد؛ end-to-end تأیید نشده. نخستین تست واقعی دقیقاً همین است.
- LibreChat در حالت host لاگین‌های اجتماعی دیگر، passkey، admin panel و ذخیره‌ی local را رد می‌کند و کارهای پس‌زمینه (schedule، trigger) لینک بدون origin tenant می‌سازند. جزئیات: `docs/multi-tenancy-host-mode.md` در ریپوی LibreChat.
- حذف tenant، LibreChat را خبر نمی‌کند و تغییر plan/name هم sync نمی‌شود.
- هنوز تست E2E واقعی با OIDC گدار انجام نشده و کلاستر staging نیست؛ اولین tenant مستقیم در production امتحان می‌شود.
