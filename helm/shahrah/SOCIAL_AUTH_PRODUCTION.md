# راهنمای استقرار ورود اجتماعی در محیط Production

این راهنما روش راه‌اندازی و بهره‌برداری ورود با Google، GitHub و Microsoft را برای گدارAI توضیح می‌دهد. تمام workloadها، Ingressها، متغیرهای ConfigMap و migrationها فقط با Helm Chart این مخزن و Argo CD مستقر می‌شوند. تنها Secretهای Kubernetes توسط Workflow اختصاصی مخزن برنامه همگام می‌شوند.

## معماری استقرار

- `godarai.ir` و `auth.godarai.ir` هر دو به workload وب‌سایت مسیردهی می‌شوند.
- `*.godarai.ir` همچنان به `tenant-admin` مسیردهی می‌شود و tenant کاربر را نشان می‌دهد.
- `admin.godarai.ir` استثنای موجود است و به `support-admin` می‌رود.
- `auth.godarai.ir` استثنای جدید است و endpoint مرکزی OAuth/OIDC را روی workload وب‌سایت ارائه می‌کند.
- گواهی `godarai-ir-tls` نام‌های `godarai.ir` و `*.godarai.ir` را پوشش می‌دهد؛ بنابراین `auth.godarai.ir` به Certificate جداگانه نیاز ندارد.
- مقدار `secrets.create` در Production برابر `false` باقی می‌ماند. Chart مقدار محرمانه تولید یا نگهداری نمی‌کند.

## پیش‌نیازهای دستی

این دو کار به دسترسی مالک حساب‌های ارائه‌دهندگان و Secretهای GitHub نیاز دارند و باید توسط اپراتور مجاز انجام شوند:

1. در هر ارائه‌دهنده یک OAuth/OIDC Application ثبت کنید و فقط callback دقیق همان ارائه‌دهنده را مجاز کنید:

   - `https://auth.godarai.ir/api/auth/callback/google`
   - `https://auth.godarai.ir/api/auth/callback/github`
   - `https://auth.godarai.ir/api/auth/callback/microsoft`

   از callback wildcard، callback مربوط به tenant و callback با HTTP در Production استفاده نکنید.

2. این GitHub Actions Secretها را در مخزن برنامه ایجاد کنید:

   - `BETTER_AUTH_SECRET`
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`
   - `OAUTH_GITHUB_CLIENT_ID`
   - `OAUTH_GITHUB_CLIENT_SECRET`
   - `MICROSOFT_CLIENT_ID`
   - `MICROSOFT_CLIENT_SECRET`

   نام Secretهای GitHub نباید با `GITHUB_` شروع شود. به همین دلیل شناسه‌ها و Secret مربوط به GitHub با پیشوند `OAUTH_GITHUB_` نگهداری می‌شوند. برای `BETTER_AUTH_SECRET` یک مقدار تصادفی قوی با حداقل ۳۲ بایت تولید کنید.

## نگاشت Secretها

Workflow زیر در مخزن برنامه، Secretهای GitHub را به Secret موجود `shahrah-secret` در namespace به نام `shahrah-production` همگام می‌کند:

```text
.github/workflows/sync-production-k8s-secrets.yml
```

نگاشت GitHub Actions به کلید runtime برنامه به این صورت است:

| GitHub Actions Secret | Kubernetes Secret key |
| --- | --- |
| `BETTER_AUTH_SECRET` | `BETTER_AUTH_SECRET` |
| `GOOGLE_CLIENT_ID` | `GOOGLE_CLIENT_ID` |
| `GOOGLE_CLIENT_SECRET` | `GOOGLE_CLIENT_SECRET` |
| `OAUTH_GITHUB_CLIENT_ID` | `GITHUB_CLIENT_ID` |
| `OAUTH_GITHUB_CLIENT_SECRET` | `GITHUB_CLIENT_SECRET` |
| `MICROSOFT_CLIENT_ID` | `MICROSOFT_CLIENT_ID` |
| `MICROSOFT_CLIENT_SECRET` | `MICROSOFT_CLIENT_SECRET` |

Workflow مقدار Secretها را در خروجی چاپ نمی‌کند و پس از همگام‌سازی فقط وجود و خالی نبودن کلیدهای runtime را بررسی می‌کند.

## ترتیب استقرار اولیه

1. پیش‌نیازهای دستی بالا را کامل کنید.
2. Workflow با نام `Sync Production Kubernetes Secrets` را از تب Actions مخزن برنامه به‌صورت دستی اجرا کنید.
3. موفق بودن مرحله‌های `Validate required secrets`، `Sync application secret` و `Verify social authentication secret keys` را بررسی کنید.
4. تغییرات برنامه را release کنید تا imageهای جدید `website`، `tenant-admin` و `control-plane` ساخته شوند و نسخه‌های آن‌ها از مسیر معمول release وارد GitOps شوند.
5. تغییرات این Chart را merge کنید. Argo CD فایل‌های `values.yaml` و `values.production.yaml` را render و sync می‌کند.
6. Hook مربوط به `migrate-main-db` باید migration شماره `056_social_auth.sql` را پیش از آماده‌شدن نسخه جدید اعمال کند.
7. وضعیت sync و سلامت workloadهای `website`، `tenant-admin` و `control-plane` را در Argo CD بررسی کنید.

Secretها باید پیش از فعال‌شدن `envFromSecretKeys` در Chart همگام شده باشند؛ در غیر این صورت Pod وب‌سایت با خطای `CreateContainerConfigError` بالا نمی‌آید. برای workload، Ingress یا restart از `kubectl apply` و `kubectl rollout restart` استفاده نکنید؛ این تغییرات باید از Chart عبور کنند.

## اعتبارسنجی پیش از merge

از ریشه مخزن GitOps اجرا کنید:

```bash
helm lint helm/shahrah
helm template shahrah helm/shahrah -f helm/shahrah/values.yaml
helm template shahrah helm/shahrah -f helm/shahrah/values.yaml -f helm/shahrah/values.staging.yaml
helm template shahrah helm/shahrah -f helm/shahrah/values.yaml -f helm/shahrah/values.production.yaml
```

در خروجی Production باید این موارد دیده شوند:

- Host دقیق `auth.godarai.ir` روی Service وب‌سایت؛
- Host دقیق `admin.godarai.ir` روی Service پنل پشتیبانی؛
- Host wildcard روی Service پنل tenant؛
- متغیر server-only به نام `GODARAI_AUTH_BASE_URL=https://auth.godarai.ir`؛
- ارجاع وب‌سایت به همه کلیدهای OAuth در `shahrah-secret`؛
- نبود `NEXT_PUBLIC_GODARAI_AUTH_BASE_URL` و نبود مقدار محرمانه در ConfigMap یا manifest رندرشده.

## آزمون پس از استقرار

1. بررسی کنید DNS مربوط به `auth.godarai.ir` به ورودی Ingress محیط Production resolve شود.
2. بازشدن `https://auth.godarai.ir` و معتبر بودن زنجیره TLS را بررسی کنید.
3. از `/onboarding` هر سه ارائه‌دهنده را آزمایش کنید. شروع ورود باید ابتدا به `auth.godarai.ir` و سپس به دامنه رسمی ارائه‌دهنده هدایت شود.
4. ساخت tenant جدید را کامل کنید و سپس ورود از `https://TENANT.godarai.ir/login` را با هر سه ارائه‌دهنده آزمایش کنید.
5. اتصال صریح حساب جدید از تنظیمات حساب را آزمایش کنید. اتصال ضمنی بر اساس ایمیل نباید رخ دهد.
6. مسیرهای OTP فعلی را نیز آزمایش کنید تا fallback ورود بدون حساب اجتماعی سالم بماند.
7. خطاهای callback، نرخ خطای ورود، مصرف ticket یک‌بارمصرف و رخدادهای امنیتی را در سامانه مشاهده‌پذیری بررسی کنید؛ token، authorization code و Secret نباید log شوند.

## کنترل‌های امنیتی

- پیاده‌سازی پروتکل به نسخه pinشده `better-auth@1.6.25` سپرده شده است؛ کنترل‌های state، nonce و PKCE در مسیرهای پشتیبانی‌شده نباید با کد سفارشی جایگزین شوند.
- cookie مرکزی host-only، دارای `HttpOnly`، `Secure` و `SameSite=Lax` است و میان tenantها به اشتراک گذاشته نمی‌شود.
- فقط ایمیل تاییدشده ارائه‌دهنده پذیرفته می‌شود.
- اتصال حساب ضمنی غیرفعال است و اتصال یک ارائه‌دهنده جدید به session تازه و ticket یک‌بارمصرف نیاز دارد.
- redirect داخلی فقط مسیر نسبی با `/` را می‌پذیرد و URL خارجی را به `/` تبدیل می‌کند.
- tokenهای OAuth در پایگاه داده به‌صورت رمز‌شده نگهداری می‌شوند.
- `DATABASE_URL`، `BETTER_AUTH_SECRET` و Secretهای ارائه‌دهندگان هرگز نباید در متغیر `NEXT_PUBLIC_*`، ConfigMap، values یا log قرار بگیرند.
- slugهای `admin` و `auth` رزروشده‌اند و نباید به tenant اختصاص داده شوند.

## چرخش Secret و restart کنترل‌شده

1. برای Client Secret ارائه‌دهندگان، مقدار جدید را در GitHub Actions Secret متناظر ثبت کنید. `BETTER_AUTH_SECRET` کلید رمزنگاری cookie، state و tokenهای ذخیره‌شده است؛ آن را مانند Client Secret عادی و به‌صورت ناگهانی جایگزین نکنید. چرخش این کلید باید با قابلیت چندکلیدی نسخه pinشده کتابخانه و آزمون بازیابی tokenها در Staging طراحی شود.
2. Workflow سینک Secret را اجرا و موفق بودن مرحله بررسی کلیدها را تایید کنید.
3. چون تغییر Secret مبتنی بر `envFrom` به‌تنهایی Pod را restart نمی‌کند، مقدار annotation نسخه Secret را در values مربوط به workload وب‌سایت تغییر دهید، برای نمونه:

   ```yaml
   website:
     podAnnotations:
       godarai.ir/secret-revision: "2026-08-01-01"
   ```

4. تغییر Chart را merge کنید و اجازه دهید Argo CD rollout را انجام دهد.
5. ورود با ارائه‌دهنده چرخش‌یافته را دوباره آزمایش کنید. مقدار قبلی را تنها پس از تایید کامل باطل کنید.

## بازگشت نسخه

- image tagها و تغییرات پیکربندی Chart را از مسیر GitOps به نسخه سالم قبلی برگردانید.
- کلیدهای OAuth را هنگام rollback فوری حذف نکنید؛ نبود آن‌ها می‌تواند rollout نسخه فعلی یا قبلی را مختل کند.
- migration اجتماعی افزایشی است؛ جدول‌های آن را در rollback اضطراری حذف نکنید.
- پس از sync نسخه قبلی، سلامت OTP و login tenant را بررسی کنید.
- اگر فقط یک ارائه‌دهنده مشکل دارد، ابتدا credential همان ارائه‌دهنده را rotate یا OAuth App آن را غیرفعال کنید و از تغییر خارج از GitOps در workloadها خودداری کنید.
