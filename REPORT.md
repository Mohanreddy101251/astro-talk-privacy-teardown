# AstroTalk (com.astrotalk v1.1.545, versionCode 545) – Static Investigation Report

Scope: static analysis only, of `base.apk` pulled from a Play-Store install on the tester's own phone (jadx 1.5.7 output in `astrotalk_re/jadx_out`). No traffic capture, no runtime logging, no backend access, no web sources. Code is R8-obfuscated, so many class names are `u0`, `b`, etc. Paths below are relative to `jadx_out/sources` (code) or `jadx_out/resources` (manifest, assets, res).

Confidence labels: **Confirmed** (code proves it exists/does X) · **Strong** · **Weak** · **Unknown**. "Confirmed" here means *the code does this*, not that it was observed running on the test phone.

---
## 1. Executive summary
- AstroTalk is a **prepaid-wallet marketplace**: users recharge a wallet, then consume per-minute chat/voice/video sessions with astrologers, plus one-off paid products (AstroMall: remedies, gemstones, e-pooja, reports), live-stream events with in-stream "gifts/donations", VIP/membership passes, and an AI persona ("Meera"/AstroBuddy).
- The Android app is a **thin client**. Pricing, balance checks, astrologer selection/ordering, queueing, offers, and Kundli/horoscope generation are all server-side calls (≈500 endpoints across 8 first-party hosts). There is **no local astrology engine** (no Swiss Ephemeris-type native lib; only Agora media libs are native).
- Biggest privacy finding: the app **reads the full installed-package list and reports to AstroTalk's backend any of 787 pre-listed apps that are installed** (OTT, gambling/fantasy, dating, stock/banking, UPI, AI chatbots, *competitor astrology apps*). Triggered at app launch and after OTP login, no user prompt seen in code.
- Other notable: Microsoft Clarity (session analytics/replay SDK) keyed to your AstroTalk userId; AppsFlyer + Firebase + Facebook + first-party RudderStack analytics; Advertising ID read and cached; an astrologer-access permission toggle set (`accessChatHistory`, `accessCallRecording`, `takeSnap`, `downloadImage`).
- Not provable from the APK: whether astrologers are human during a given session, astrologer verification process, commission split, refund formulas, recommendation algorithm.

## 2. Reconstructed workflows (from endpoint names + DTOs; behaviour server-side = Strong, not Confirmed)
1. **Onboarding/login:** `login/send-otp`, `verify-otp/v2` (+email variants), Truecaller one-tap, OTPLESS (WhatsApp/other-app login), Firebase Auth. Install source/referrer saved (`user/save/app/install/source`, `…/referrer/info`), device registered (`user-device/create`).
2. **Browse:** `freeAPI/consultant/get-list/filter|sorting`, `recommendation/get`, `get-connected-consultants`, `membership/list`. Params include `userId, languageId, categoryId, hardwareId, countryCode, isRecommended, mustTry, isOfferV3, isPoAstrologer` → server filters/sorts/personalises.
3. **Start consultation:** balance/price check `consultant/get/consultant/price` (userId+consultantId+serviceId+timezone+appVersion) → if low, `recharge/amount/get/by/userId` with `minimumDeltaAmountToStartService` returns recharge options → `call-chat/queue/create-token/v3|v4` → waitlist/queue (`queue-token/user/waitlist/get/v3`, `consultant/get/total/wait/time`, hold/pause/cancel) → **intake form** (`chat/order/fill-intake-form`, `calling/fill-intake-form`) → chat order accept/cancel/complete (`chat/order/accept/byUser/v2`, `…/completed/v2`).
4. **Calls:** Agora RTC (`calling/agora-voip/*`, `child/call/*`, `calling/internet/*`; Agora App ID hard-coded in `controller/AppController.java:k()`).
5. **Live events:** `live/event/*` (join, donate, products, subscribe, price, wait-time).
6. **Commerce:** AstroMall cart/buy-now, address, COD (`product-type/order/set/to/cod`), prescriptions/remedies.
7. **Post-session:** rating/review, NPS, management feedback, "continue chat" (`queue-token/create/chat-continue`), order share, invoice.

## 3. Astrologer onboarding, matching, consultation logic
- **Onboarding/verification (astrologer side):** not in this app (consumer app). Confirmed only that the UI *displays* "Verified Astrologers", a green tick, and "Astrotalk Assured … personally verified by our CEO" (`res/values/strings.xml:633,1907,5477`). What verification consists of: **Unknown**.
- **Matching:** `isRecommended`, `mustTry`, `isPoAstrologer`, `isOfferV3`, `recommendation/analytics/create`, `featureAstrologerMatching`, `featureWhomToConnect`, `featureConsultantTags`, `featurePriorityTokenWaitlist`. So ranking/priority exist; the algorithm is server-side → **Unknown**.
- **Unavailable/rejects:** waitlist with timeouts, `smart/waitlist/convert/to/paid`, `featureWaitlistRedirect` (redirect to another astrologer), "Ask Many" holds money and auto-refunds on no reply (`strings.xml:300`).
- **Session end:** `calling/vendor/call/checkAndEnd`, `calling/internet/call/end`, `chat/order/completed/v2` – server-adjudicated.

## 4. Astrology calculation / prediction generation
- Kundli/horoscope/panchang/dasha/ashtakvarga/divisional/transit endpoints (`kundli/*`, `horoscope/daily/generate/v5`, `panchanga`, `dasha_complete`, `yogini_dasha_complete`, `ashtakvarga/complete`, `combined/*`, `find/combination`) are **remote calls** to `api.prod.astrotalk.in` and `api.kundali.astrotalk.com/v1/` (**Confirmed**: remote; **Unknown**: engine/vendor behind it). No on-device ephemeris library found in native libs (Confirmed).
- Inputs sent: name, DOB, time, place of birth (+lat/long, country ISO), gender, partner DOB/time/place/lat/lon, occupation field (sent empty in sampled forms), saved as birth-detail profiles (`birthdetail/save/planets`).
- **Deterministic vs human vs AI:** charts/reports = server computation (Strong); daily horoscope = server-generated (generator unknown); astrologer answers = human *or* other (see §6); "Meera" = AI persona (see §6). Personalisation from history: not provable; `user/get/experiments`, `recommendation/analytics` show behavioural targeting exists.

## 5. Payment, wallet, pricing, commission
- **Wallet:** `wallet/getMoney`, invoices (`invoice/generate/invoice/receipt/wallet`), `payment-log/*`, `auto-debit/*` (e-mandate autopay, `user/auto/debit/v2`), "pay later" module, gift-card redeem, saved cards, credits (`api/credit/*`).
- **Gateways (SDKs bundled + endpoints):** Razorpay (incl. custom checkout), Paytm (`securegw.paytm.in`, initiate-payments V2), PhonePe, Easebuzz, PayU, Stripe, PayPal (global), UPI app handoff.
- **Pricing:** per-minute price is obtained from the server per consultant/service (`consultant/get/consultant/price`, `consultant/get/price`); "fixed-minute" packages validated server-side (`fixed/minute/validate`); strings show first-chat ₹1/min, free first chat, "first N minutes free", flash/first-session offers, cashback % on recharge, coupons (`offer/promotional/applyCode/v2`, `coupon/isToGiveCoupon`).
- **Deduction/refund/commission formulas:** **Unknown** (server). Client only displays balances and refund policy strings (e.g. group-chat orders "non-refundable", `strings.xml:1921`; payment failure refunds 4–7 days).
- **How it makes money (Strong):** wallet recharges converted into per-minute consultation spend; AstroMall product sales; live-event gifts/donations; VIP memberships/passes; offers that lower first-session cost to start the habit.

## 6. Astrologer authenticity & automation evidence
- **Confirmed:** an AI persona exists: UI strings "Ask Meera"/"Hi, I'm Meera" and a **"Powered by AI"** badge (`strings.xml:359,1985,3945`; `featureAstroBuddy`, endpoints `group/chat/automated/message/add`, `chat-assistance-manager/*`). So AI use *is disclosed* at least for that feature.
- **Confirmed:** "automated message" endpoint in group chat (`AstroMall/group/chat/automated/message/add`) – automated messages exist in group chats.
- **Indicated:** `OnboardingThroughChatDummyGBDTO.json` asset and a `dummychat` package → scripted/templated onboarding chat. `featureAskMany` suggests one question routed to many astrologers.
- **Not provable:** that a paid 1:1 chat/call answer comes from a human astrologer; the app only exposes `ChatMessageRole {user, consultant}`. Whether astrologers are independent contractors or managed: **Unknown**. Reviews/ratings: client posts `rating-review/create`; whether verified-purchase only: **Unknown**.
- Don't label any astrologer genuine/fake from this evidence.

## 7. Personal-data inventory (collected → destination)
| Data | Evidence | Collected | Sent to |
|---|---|---|---|
| Phone/email, OTP | login endpoints, Truecaller/OTPLESS | Confirmed | AstroTalk; Truecaller/OTPLESS if used |
| Name, DOB, time, place, gender, partner details | intake + birthdetail endpoints | Confirmed | AstroTalk API (and shown to the astrologer: Strong) |
| Chat/call content | `chat/message/send-message/v3`, Agora | Confirmed | AstroTalk chat host; Agora (media relay) |
| **Installed apps (787-list match)** | `utils/ExternalPackageTracker*`, `u0.java`, `assets/apppackges.json`, `controller/b.java:573` `POST user/apps/installed?device_id=` | **Confirmed in code** | AstroTalk (`api.prod.astrotalk.in`) |
| Device model/manufacturer/OS/screen/appVersion/deviceId | `user-device/create` | Confirmed | AstroTalk |
| Advertising ID | `AppController.java:~460` `AdvertisingIdClient`; saved to prefs `saveadd_id` | Confirmed (read+stored); onward sending: Strong via AppsFlyer/Firebase | AppsFlyer/Google (Strong) |
| Install referrer/source | `user/save/app/install/referrer/info` | Confirmed | AstroTalk |
| FCM push token | `update_device_token` | Confirmed | AstroTalk/Google |
| Timezone, country (by IP), language | many endpoints, `get/countryCodeByIp` | Confirmed | AstroTalk |
| User ID as analytics ID | `Clarity.setCustomUserId`, `AppsFlyerLib.setCustomerUserId` (`AppController.java:700,936`) | Confirmed | Microsoft Clarity, AppsFlyer |
| Screen/session interactions | Clarity SDK init `<redacted-project-id>`; only one explicit `maskView` call found | Confirmed init; what Clarity uploads: Strong/Unknown | Microsoft |
| Behavioural events | RudderStack to **first-party** `rudder-prod.astrotalk.in`, Firebase, AppsFlyer, Facebook SDK, GTM container `GTM-584FPZD` asset | Confirmed present | AstroTalk / Google / AppsFlyer / Meta |
| Profile views & dwell time | `profile/visitor/create`, `…/save/duration` | Confirmed | AstroTalk |
| Location | Manifest has coarse+fine; **no first-party location API calls found**; location by IP (`get/countryCodeByIp`); place search via Google Places / postalpincode | Permission present; usage by libs: Unknown | – |
| Contacts/SMS/call-log | **No such permissions in manifest** | Not requested | – |
| Clipboard | Read (`getPrimaryClip`) not found; clipboard writes in chat/refer screens | No read evidence | – |
| Camera/mic | Declared; used for video/voice calls and image upload | Confirmed | Agora/AstroTalk |

## 8. Third-party / endpoint map
First-party hosts (counts of references in code): `api.prod.astrotalk.in` (main), `api.paidchat.astrotalk.com`, `api.supportchat.astrotalk.com`, `api.live.astrotalk.com`, `api.kundali.astrotalk.com`, `api.astromall.astrotalk.com`, `api.consultant.list.astrotalk.com`, `api.orderview.astrotalk.in`, `rudder-prod.astrotalk.in`, `aws.astrotalk.com` (**plain http** for astrologer images), `ishwar.astrotalk.com`, `chat.astrotalk.com`, `maintenance.astrotalk.com`.
Third parties (SDKs bundled): Agora (RTC), Razorpay, Paytm, PhonePe, Easebuzz, PayU, Stripe, PayPal/CardinalCommerce, Firebase (Auth, Analytics, FCM, Remote Config), AppsFlyer, Microsoft Clarity, Facebook SDK, Amplitude package present, Truecaller SDK, OTPLESS, Plivo, WhatsApp, Google Maps/Places, Google Tag Manager, Chucker (debug HTTP inspector package is in the release build). Whether each SDK actually transmits in your usage requires traffic capture – **Unknown** until observed.

## 9. Background tracking
- `RECEIVE_BOOT_COMPLETED`, FCM push, foreground services (data sync, microphone, phone call), `POST_PROMOTED_NOTIFICATIONS`, `USE_FULL_SCREEN_INTENT` → re-engagement/call-style full-screen notifications are possible (Strong).
- `user/app/launch` posted at start; installed-app scan runs from `SplashActivity` and `OTPVerificationActivity` (foreground). Interval/dedupe logic is in `u0.b` which jadx failed to decompile → frequency **Unknown**.
- AppsFlyer attribution + `ACCESS_ADSERVICES_*` (Privacy Sandbox) permissions present.

## 10. Hidden business rules & engagement mechanics (all Confirmed to exist; thresholds Unknown)
Experiment/segmentation (`user/get/experiments`, `exp-config`, `capture/feature/evaluation/data`, `user/update/user/feature/flag`) · personalised recharge ladders (`recharge/amount/get/by/userId`) · new-user "PO" offers and cashback timers (`featureCashbackOfferTimer`, `offer/v3/po/status/new-user`) · loss-aversion copy ("Are you sure you want to lose your first free chat?" `strings.xml:1696`) · gift offers, magic box, daily-grace/pass, VIP/loyalty memberships, referral (`referral/v2/*`), priority-token waitlist, one-tap hold/auto-debit, "continue chat" nudges, "psychic of the week", testimonial videos, star messages, live donations, weekly timetable.

## 11. Risk assessment
- **High:** installed-app profiling incl. gambling, dating, loans, banking, health-adjacent and competitor-app signals, with no consent UI found in the code path reviewed. Contrast: no QUERY_ALL_PACKAGES, so it uses a long `<queries>` allow-list + `getInstalledPackages`. Play-policy compliance: not for me to judge.
- **Medium:** Clarity session capture tied to real user ID on screens that contain birth details, chats, payments (masking coverage unknown); AdID + userId joined in AppsFlyer; astrologer-access toggles (chat history, call recording, snapshots) imply recordings may exist.
- **Medium:** plain-HTTP asset host; debug tooling (Chucker) bundled; hard-coded SDK keys/IDs (Agora, AppsFlyer, RudderStack writeKey, Clarity) – normal but extractable. No certificate pinning found in first-party code (`CertificatePinner` search: none) → traffic capture on your own phone is feasible with a user-installed CA, subject to library behaviour.
- **Low:** no contacts/SMS/call-log permissions.

## 12. Evidence register
| # | Finding | Source |
|---|---|---|
| E1 | Permission list | `resources/AndroidManifest.xml` |
| E2 | Installed-apps tracker | `sources/com/astrotalk/utils/ExternalPackageTracker$getInstalledTrackedApps$1.java` (getInstalledPackages + match against `assets/apppackges.json`), `utils/u0.java`, call sites `SplashActivity` and `OTPVerificationActivity` (`u0.a(...)`), API `controller/b.java:573` |
| E3 | 787-app list incl. competitors | `resources/assets/apppackges.json` |
| E4 | Clarity init + userId | `controller/AppController.java:699-700` |
| E5 | AppsFlyer init + userId | `AppController.java:928-942` |
| E6 | AdID read/stored | `AppController.java:460-468` |
| E7 | RudderStack first-party endpoint | `rudderstackSdk` / `rudder-prod.astrotalk.in`, writeKey in code |
| E8 | Host constants | `AppController.java:~990` (DOMAIN_* strings) |
| E9 | Astrologer-access permissions | `controller/b.java:625,764` `user/permission` |
| E10 | AI persona/disclosure | `strings.xml:359,363,1985,3945` |
| E11 | Verification claims (display only) | `strings.xml:633,1907,5477` |
| E13 | Network config | `res/xml/network_security_config.xml` (cleartext only for localhost/LAN IPs) |
| E14 | No local astrology engine | native libs in `split_config.arm64_v8a.apk`: only Agora, androidx, libtoolChecker, video_dec |

## 13. Unknowns / limitations
- Everything server-side: pricing and commission math, refund calc, matching algorithm, astrologer vetting, human-vs-bot in paid chats, what astrologers see exactly.
- What each SDK actually sends on the wire; whether Clarity masks sensitive screens; installed-app upload frequency/consent gating (`u0.b` not decompiled).
- Not analysed in depth: Facebook/Amplitude/Plivo/Truecaller call sites, Firebase Remote Config values, split APK resources, `libtoolChecker.so` purpose (name suggests tamper/root checks; unverified), Kotlin classes where jadx errored.
- **Next authorised steps:** (a) capture your own phone's traffic (mitmproxy with a user CA; do not defeat pinning if found); confirm `user/apps/installed` payload and frequency; (b) `adb logcat` + `run-as`-style inspection is not possible on a release build, so use an `adb backup`-free approach: Settings → Data safety, or Android's Privacy Dashboard for permission use; (c) a full jadx smali dump of `u0.b` to read the gating logic.

---
# ADDENDUM A – Business-logic deep-dive (code only, no traffic needed)
Sources: DTOs under `sources/com/astrotalk/{domain,models,featureChat}`, `res/values/strings.xml`, `controller/b.java`.

## A1. Session start funnel (Confirmed from request/response models)
1. **Price + balance gate.** `consultant/get/consultant/price` returns `Data{price, priceForeign, priceInCurrency, pricingPlan, fo, globalCall/Chat/Video, countryCode, myPartForeign}` (`models/required_balance/Data.java`). So price is **per astrologer, per service (chat/call/video), per country/currency**, and tied to a `pricingPlan` id. `myPartForeign` is returned to the app but never read by it; its meaning (possibly a revenue-share figure) is **Unknown/Weak** – do not treat as proven commission data.
2. **Recharge ladder.** If balance is short, `recharge/amount/get/by/userId` takes `minimumDeltaAmountToStartService` + `consultantId` + `serviceId` and returns a server-designed ladder (`AddMoneyModel`: `quickRechargeConsultantPriceParamsList`, `minimumBalanceQuickrechargeDefaultSelection`, `amountDesign` badges, `toShowInchatDiscounts`, `paymentOfferConfig`, `platformFeeObject{actualAmount, discountedAmount}`, `waiveGst`, `isGstDesign`). → recharge options are **computed per user/astrologer**, include a **platform fee** shown with a "discounted" strike-through and optional GST waiver (Confirmed to exist; rules Unknown).
3. **Queue token.** `create-token/v4` body (`CreateTokenV4RequestBody`): `queueToken, intakeForm, birthDetailId, clientMetaData, preAppendedMessages, isAvailableForDirectChat, isClaimRtsPoFlow, timeLimitInMinForFreeChat, freeTimeLimitInMinForSmartWaitlist`. Meaning: the **client pre-writes opening messages** (`preAppendedMessages`) into the chat; there are **free-time limits** attached to free chat and a **"smart waitlist"** that gives free minutes while waiting; `smart/waitlist/convert/to/paid` flips that order to paid (`chatOrderId`+`messageId`) → free minutes are a conversion funnel into paid time (Strong).
4. **Offline astrologers can be queued.** String: "X is offline. If you join the waitlist, we will notify them to take the session, if possible." (`strings.xml:389,391`). → you can pay-queue for someone who isn't online; fulfilment is best-effort.
5. **Re-routing on exit.** Leaving a waitlist triggers "join the waitlist of these trending astrologers" (`:2354-2355`) → retention/redistribution of demand.

## A2. During the session
- **Transport:** chat events arrive via **MQTT** (`atnetworkmodule/mqtt/*`, `MqttPayloadDto`) plus REST polling (`get-latest-messages-batch`). Voice/video via Agora. **The server ends sessions**: UI text "Chat ended due to low balance. Recharge to continue" (`:859`); `calling/vendor/call/checkAndEnd`. The client is not the billing clock (Strong).
- **Mid-session upsell:** `DuringCallRechargeConfig` (`rechargePromptTitle`, `timerPreFixText`, `shouldShowAdditionalMinutesNudge`, `toAllowDirectCheckoutOnAmountClick`) and `quickRechargeDuringChatDesignParams` → in-call recharge prompts with countdown/“additional minutes” nudges (Confirmed). Copy: "Tip: 90% users recharge for 10 mins or more." (`:5275`) – an anchoring nudge; the statistic is **unverified**.
- **Auto top-up:** Auto Pay: charge now and **auto-debit whenever wallet < threshold** (`strings.xml:587`; `auto-debit/*`, `AddMoneyModel.autoPayV6Config`, `recurringPaymentV4InBetweenChat`) → recurring wallet refills during chats (Confirmed to exist; enrolment is opt-in via UI: Unknown default).
- **Ask Many:** amount **held** and released to each astrologer **only when they answer**; auto-cancel + refund on no reply (`:300`) – the only explicit "pay on delivery" mechanic found.
- **Gifts/donations:** live-stream gifts are "voluntary and do not guarantee a consultation" (`:1880`); donation blocked while on a call (`:517`).

## A3. Access tiers (monetised queue priority)
- **VIP:** "Become a VIP member at ₹999/month and skip the queue" (`:5528`); "top of the queue because you are our VIP member" (`:5671-5672`); endpoints `membership/subscription/vip/*`.
- **Loyal Club / Daily Pass:** "Lesser wait time for loyal club" (`:2452`), minimum wallet balance to activate (`:5699`), Daily Pass activated **from wallet** (`:1734`).
- **Priority/skip:** "Priority Session", "Skip the waitlist" (`:3970,2403`); "missed call earlier → Astrotalk will prioritise your call ahead in the waitlist if you connect now" (`:2405`) – re-engagement via queue position.
- **Premium astrologers** ("consulted by Bollywood celebrities, cricketers & CEOs"; "personally verified by our CEO", `:631-635`) carry deliberate wait times, which then sell priority. The claims are marketing copy; unverifiable from code.

## A4. Offers & loss-aversion mechanics
First chat ₹1/min or free (`:1638-1700`), "first N minutes free", flash offers, first-session fixed price, cashback on recharge with caps (`:1659`), coupons, referral, "Are you sure you want to lose your first free chat?" exit prompts, cashback timers, daily-grace streak gifts (day N gift), `featureChatBlur` (blurred content, likely paywall teaser – Weak, name only), callback requests (free callback within 12–24 h for products, `:4003`).

## A5. What this means for "how it makes money" (Strong)
Revenue = recharge volume × consultation spend per minute. Levers the product visibly pulls: (a) subsidised first minutes → conversion to paid; (b) deliberate scarcity (waitlists on top astrologers) → sell VIP/Loyal priority; (c) recharge ladders sized to astrologer price with in-call top-up prompts and auto top-up → raise stored balance and uninterrupted spend; (d) platform fee/GST presentation on recharge; (e) AstroMall remedies surfaced after consultation (`product-type/*`, `astromall/select/consultant`); (f) live-stream gifting. Platform-vs-astrologer split: **Unknown** (only an unexplained `myPartForeign` field).

## A6. Still not answerable from the APK
Billing granularity (per second vs per minute), rounding, exact refund rules on dropped sessions, who the "consultant" role is during a paid chat (human/automated), astrologer payout.

---
# ADDENDUM B – What leaves the test phone (data-flow focus; code evidence, not wire-verified)
**Correction to §7:** an earlier grep missed that the app reads `Settings.Secure.ANDROID_ID` (constant `EventsNameKt.DEVICE_ID = "android_id"`; used in `SplashActivity:564` and many activities). It is stored as pref `hardware_id`.

## B1. To AstroTalk's own servers (Confirmed in code)
| Data | How it's sent | Evidence |
|---|---|---|
| **ANDROID_ID** (stable per-device ID) | `deviceId` on `user-device/create`; `hardware_id` header; `hardwareId` query param on astrologer list/price/profile calls | `SplashActivity:564-567`, `controller/b.java:1331`, `AstrologerProfileWebViewActivity:1728` |
| **Google Advertising ID** | `gpsAdId=` query param alongside `user_id` and FCM token on `user/api/v1/update_device_token` | `authPackage/b.java`, `authPackage/presentation/g.java` (3 call sites), pref `saveadd_id` set in `AppController:469` |
| FCM push token + user ID | same call | as above |
| Device model, manufacturer, Android version, app version, screen size & density | `user-device/create` query params | `controller/b.java:1331` |
| **Installed apps from a 787-app list (name + package)** | `POST user/apps/installed?device_id=…` JSON list | `utils/ExternalPackageTracker*`, `assets/apppackges.json` |
| Install referrer/source | `user/save/app/install/referrer/info`, `…/source` | `controller/b.java` |
| Timezone, language, country (IP lookup), app version | on most calls | multiple |
| Birth details (name, DOB, time, place + lat/long, gender, partner's details) | intake forms, `birthdetail/save/planets` | `activities/intake/*` |
| Chat messages, voice/video | send-message, Agora | chat endpoints |
| Which astrologer profiles you open and for how long | `profile/visitor/create`, `…/save/duration` | `controller/b.java:1166` |
| App-launch ping, A/B experiment assignment, permission toggles (`accessChatHistory`, `accessCallRecording`, `takeSnap`, `downloadImage`) | `user/app/launch`, `user/get/experiments`, `user/permission` | `controller/b.java` |
| Behavioural events (screens, clicks, impressions, payment funnel steps) | RudderStack at `rudder-prod.astrotalk.in` (first-party) | `rudderstackSdk/*` (e.g. `trackLazyRowImpressions`, checkout click/field/state enums) |

Net effect: AstroTalk can join **phone number/user ID ↔ ANDROID_ID ↔ Advertising ID ↔ FCM token ↔ installed-app profile ↔ birth data ↔ chat content** on its own side.

## B2. To third parties (SDK present + initialised in code; payloads not inspected)
- **Microsoft Clarity**: initialised with your AstroTalk user ID (`AppController:699-700`). Clarity records screen interactions/replay; only one `maskView` call found → whether birth-detail/chat/payment screens are masked is **Unknown**.
- **AppsFlyer**: `init` + `setCustomerUserId(userId)` (`AppController:928-942`); AppsFlyer by default collects advertising ID, device/OS info, IP, install and in-app events (SDK behaviour, Strong).
- **Firebase Analytics / FCM / Auth / Remote Config** (Google) and **Facebook SDK**: present; Firebase Analytics default data includes app instance ID, device/OS info, events.
- **OTPLESS / Truecaller** (login): helper code `utils/u1.java` builds **SIM carrier name, MCC/MNC, SIM country, SIM-inserted flag, network type (WiFi/mobile)**; this is OTPLESS-SDK-derived code, so those fields go to the OTPLESS login flow, not evidently to AstroTalk (Strong).
- **Agora**: audio/video relay for calls. **Payment SDKs** (Razorpay, Paytm, PhonePe, Easebuzz, PayU, Stripe, PayPal): receive payment details you enter in their screens; they also see device data per their own SDKs.
- **Google Maps/Places**: place-of-birth search text.

## B3. What the app does NOT send (by code/manifest)
Contacts, SMS, call logs, files/photos (except images you choose to upload), clipboard contents (no read found), precise location from GPS (permissions declared, but no first-party location API calls found; country is inferred from IP).

## B4. Triggers
Foreground at **app launch** (`SplashActivity`: ID/device registration, installed-app scan, launch ping) and **right after OTP login** (`OTPVerificationActivity`: installed-app scan). FCM-token/AdID sync happens on token refresh and login paths. Background transmission cannot be proven without observation; boot receiver + FCM exist.

## B5. Unknowns that only observation can settle
Exact JSON of the installed-apps upload and how often it repeats (`u0.b` gating undecompiled); whether you were asked for consent anywhere in the UI flow; what Clarity/AppsFlyer/Facebook actually uploaded in your sessions. A host-level capture (PCAPdroid) would show the destinations and timing; it can't show contents because the app trusts only system certificates.

---
# ADDENDUM C – Installed-app upload gating resolved (`utils/u0.b`, read via jadx fallback mode: `astrotalk_re/u0out/u0_fb.java`)
- Runs when the pref `execute_24h_check` is 0 (first run) **or older than 604,800,000 ms = 7 days** (the pref name says "24h", the code uses 7 days). Then it scans, filters against `apppackges.json`, and posts matches.
- Guard flags are only an in-memory "already running" boolean and a mutex. **No consent/opt-out preference is read in this method** (Confirmed for this method; a UI consent elsewhere, if any, would have to gate the callers `SplashActivity` / `OTPVerificationActivity`, which call it unconditionally in the code reviewed).
- So: **first launch/login, then repeated at least weekly** while the app is opened.

---
# ADDENDUM D – Observed host-level traffic (PCAPdroid, the test phone, 2026-11-23 20:29:16 → 20:32:40, ~3.4 min, app UID 10035)
Source: `astrotalk_re/capture/PCAPdroid_23_Nov_20_33_11.csv` (139 non-DNS flows). Metadata only (no payload/TLS decryption). Bytes are totals for the session; "sent" = phone → server.

| Destination | Owner | Uploaded | Notes |
|---|---|---|---|
| `rudder-prod.astrotalk.in` | AstroTalk (RudderStack proxy) | **~120 KB** (6 conns) | Largest upload of the session = behavioural event stream. Also `api.rudderlabs.com` (2.7 KB) = RudderStack's own cloud |
| `api.prod.astrotalk.in` | AstroTalk main API | ~70 KB (21 conns) | Starts <0.2 s after launch (first conns 20:29:16.9) |
| `rtx-prod.astrotalk.in` :1883 (TLS) | AstroTalk MQTT realtime | ~45 KB up / 76 KB down, held open ~2.7 min | Persistent realtime channel opened at launch |
| `user-retentions.astrotalk.in` | AstroTalk | ~7 KB, repeated at 20:29, 20:32 | Name indicates a retention service; **not in my static endpoint list** |
| `payments-api.astrotalk.in`, `cdn-exp-api.astrotalk.in`, `api.kundli-common.astrotalk.com` | AstroTalk | 14 KB / 4 KB / 4.7 KB | Payments/experiments config contacted at launch, before any purchase |
| `aws.astrotalk.com` | AstroTalk CDN | 93 KB up, **~8 MB down** | **Plain HTTP port 80 flows confirmed** (18 flows, ~6.6 MB received (mostly images), e.g. flows at 20:31:45 and 20:32:10); also HTTPS |
| `events.otpless.tech`, `sigma.otpless.app` | OTPLESS (3rd party) | ~34 KB total | Login SDK talks to its servers at launch though you didn't sign in during the capture window |
| `h0zv1q.*.appsflyersdk.com` (inapps, launches, conversions, register, cdn-settings, pia, gcdsdk, dlsdk) | AppsFlyer (3rd party) | ~48 KB, 10 sub-hosts | `register`, `launches`, `conversions` = install/launch/attribution reporting; repeated again at 20:32:09 (second launch cycle) |
| `graph.facebook.com` | Meta (3rd party) | ~17 KB (8 conns) | Facebook SDK is active |
| `firebaselogging-pa`, `firebaseinstallations`, `firebaseremoteconfig`, `firebase-settings.crashlytics`, `crashlyticsreports-pa` | Google | ~25 KB | Analytics logging, installation ID, remote config, crash reports (6.6 KB crash report upload at 20:32:09) |
| `www.google-analytics.com`, `ssl.google-analytics.com` | Google | ~3 KB | Google Analytics (web/GTM style) hits |
| `www.recaptcha.net`, `www.gstatic.com` | Google | ~28 KB | reCAPTCHA loaded in-app |
| `i.postimg.cc` | Postimages (3rd-party image host) | ~6 KB, 11 conns incl. repeated failed/zero-reply TCP | Third-party image host, not AstroTalk-controlled |
| `api.razorpay.com` | Razorpay | 3.7 KB at 20:32:17 | Payment SDK contacted (the tester reached a recharge/payment screen) |

## What the capture confirms
- **Confirmed (observed):** AppsFlyer, Facebook, Firebase/Crashlytics, Google Analytics, OTPLESS, RudderStack and many AstroTalk services all connect **within the first ~2 seconds of launch**, before any action by you.
- **Confirmed:** plain-HTTP (port 80) traffic to `aws.astrotalk.com` (unencrypted images; anyone on your network path can see which astrologer images/pages you fetch).
- **Confirmed:** a persistent MQTT channel and a "user-retentions" service are used; both are new relative to the code-only findings.
- **Two launch cycles** (20:29:16 and 20:32:09) each re-fire AppsFlyer, Facebook, Rudder, Crashlytics: analytics repeat on every app start.
- **Not observed:** `clarity.ms` (Microsoft Clarity) — no connection in this window. Static code only initialises it when a user ID is stored, so it may simply not have run for you in this window; **unresolved**.
- **Cannot be read from this capture:** contents. In particular, whether the installed-apps list was uploaded in this session (it would be a POST to `api.prod.astrotalk.in`, indistinguishable from other calls by metadata). The 7-day gate in `u0.b` means a later session may not repeat it.
- DNS-level note: every host appears under the app's UID, i.e. attributed to AstroTalk itself, not another app.
