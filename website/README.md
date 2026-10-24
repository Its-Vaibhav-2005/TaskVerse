# TrackVerse public pages

Static homepage and privacy policy, prepared for free GitHub Pages hosting. These files contain no OAuth configuration, tokens, SQLite databases, or user habit records.

Publish only the website folder to a public repository. Do not upload the full desktop workspace. Use `index.html` as the homepage and `privacy.html` as the privacy policy. The maintainer contact matches the Google OAuth project's designated support contact.

## Product video

The homepage plays `media/TrackVerse-Cinematic-1080p.mp4` (3:25, 1920 × 1080, 30 FPS). The approved video was copied from the local `dist/media` release assets. Publish its matching `TrackVerse-Cinematic.vtt`, `.srt`, and `TrackVerse-Cinematic-Transcript.md`, along with `walkthrough-poster.png` and `walkthrough-preview.gif`. The README preview and homepage share these media assets. `walkthrough.js` connects the homepage chapter buttons to the video; update their times if the edit changes.

Pushes to `main` that change `website/**` trigger `.github/workflows/pages.yml`, which deploys this folder to GitHub Pages. Keep video files below GitHub's 100 MB per-file limit. The earlier quick-start assets remain available for existing direct links.

Before public OAuth rollout:
1. Host these pages at a stable HTTPS address, without a login wall.
2. Verify ownership of the hosting URL/subdomain in Google Search Console using its supplied HTML verification file or tag.
3. Set the real homepage and privacy-policy URLs in Google Auth Platform → Branding and add the corresponding authorized domain. Never use an unrelated site's policy or claim ownership of an unverified domain.
4. Save, then change Audience from External / Testing to In production. Google may request further brand verification; publishing is not a claim that Google has verified the app.
5. Test consent from an account that was never on the tester list, then verify a successful cloud backup and recovery.

Keep Google Cloud billing disabled and do not enable paid quota increases. Standard API use has quotas; the app retries quota errors and preserves local data.

## Google Search visibility

The homepage identifies TrackVerse as a free Windows habit tracker by Vaibhav Pandey, with matching visible content, search metadata, social previews, and Person/WebSite/SoftwareApplication structured data. All three public HTML pages have canonical URLs and are listed in `sitemap.xml`. Keep structured data and download/version information consistent with the visible release.

After deployment:
1. Open https://search.google.com/search-console/ and add a **URL prefix** property: `https://its-vaibhav-2005.github.io/TaskVerse/` (include the trailing slash).
2. Choose **HTML tag** verification. Add the exact Google-supplied `google-site-verification` meta tag to the homepage's `<head>`, deploy, then click Verify. Keep the tag in future releases. Do not invent a verification token. Domain verification requires DNS control and is not appropriate for the shared `github.io` domain.
3. Submit `https://its-vaibhav-2005.github.io/TaskVerse/sitemap.xml` in the Sitemaps report.
4. Inspect the homepage URL, test the live URL, and request indexing. Check the themes and privacy URLs for errors as well.
5. Monitor indexing and search impressions for TrackVerse, Vaibhav Pandey, and relevant habit tracker queries. Link the site from the maintainer's public GitHub profile and other relevant profiles when authorized.

This is a GitHub Pages project site: Google reads robots rules at `https://its-vaibhav-2005.github.io/robots.txt`, not `/TaskVerse/robots.txt`. A project-level robots file would have no crawling effect, so the sitemap is submitted directly in Search Console. A missing root robots file (404) normally allows crawling; check for restrictive rules if the account's root site changes.

SEO changes and sitemap submission cannot guarantee indexing, a date, or first position. Brand and creator searches are more focused targets than the broad “habit tracker” query. Search Console access is needed to confirm Google's indexing status.
