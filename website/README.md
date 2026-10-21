# TrackVerse public pages

Static homepage and privacy policy, prepared for free GitHub Pages hosting. These files contain no OAuth configuration, tokens, SQLite databases, or user habit records.

Publish only the website folder to a public repository. Do not upload the full desktop workspace. Use `index.html` as the homepage and `privacy.html` as the privacy policy. The maintainer contact matches the Google OAuth project's designated support contact.

Before public OAuth rollout:
1. Host these pages at a stable HTTPS address, without a login wall.
2. Verify ownership of the hosting URL/subdomain in Google Search Console using its supplied HTML verification file or tag.
3. Set the real homepage and privacy-policy URLs in Google Auth Platform → Branding and add the corresponding authorized domain. Never use an unrelated site's policy or claim ownership of an unverified domain.
4. Save, then change Audience from External / Testing to In production. Google may request further brand verification; publishing is not a claim that Google has verified the app.
5. Test consent from an account that was never on the tester list, then verify a successful cloud backup and recovery.

Keep Google Cloud billing disabled and do not enable paid quota increases. Standard API use has quotas; the app retries quota errors and preserves local data.
