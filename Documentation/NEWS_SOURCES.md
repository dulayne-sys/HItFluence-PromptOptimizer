# Editorial briefing: provenance, privacy and source rules

## Source of truth

The initial publisher inventory follows the user's private HitCode repository `Sources/HitCode/News/NewsSources.swift`, inspected 2026-11-17. All source URLs may change and must be validated on the user's Mac. This implementation does not imply any current feed endpoint is guaranteed available.

| Publisher | Feed | Default |
|---|---|---|
| Apple Developer | https://developer.apple.com/news/rss/news.rss | Enabled when news enabled |
| Swift.org | https://www.swift.org/atom.xml | Enabled |
| WebKit | https://webkit.org/feed/ | Enabled |
| Apple Machine Learning Research | https://machinelearning.apple.com/rss.xml | Enabled |
| Google DeepMind | https://deepmind.google/blog/rss.xml | Enabled |
| Hugging Face | https://huggingface.co/blog/feed.xml | Enabled |
| GitHub Blog | https://github.blog/feed/ | Enabled |
| GitHub Security | https://github.blog/security/feed/ | Enabled |
| OpenAI | https://openai.com/news/rss.xml | Disabled by default (feed validated 2026-11-17) |
| GitHub Changelog | https://github.blog/changelog/feed/ | Disabled by default (feed validated 2026-11-17) |

**Publisher-only shortcuts, without any automatic feed scraping:** https://www.superhuman.ai/ and https://codenewsletter.ai/.

## Contract

- **Opt-in:** `PromptStudio.NewsEnabled` starts as false. No Home fetch occurs otherwise.
- **Source selection:** each official publisher can be enabled/disabled independently.
- **Fetch:** HTTPS URLSession metadata only, one source at a time, size <= 2MB, timeout 12 sec, manual refresh or stale refresh after 30 min.
- **Parsing:** RSS/Atom headline, destination URL, publication date and first 200 plain text summary characters. No full-page fetching.
- **Cache:** Application Support JSON, atomic write, 160 article limit, saved IDs preserved across refresh.
- **Provenance:** publishers and links accompany headlines. URL must be HTTPS; failed feeds do not create synthetic stories.
- **Security:** user opens links in a nonpersistent WebKit viewer. News retrieval is separate from model inference, which runs on this Mac.

## Known v1 limitations

- Feed XML may evolve; RSS/Atom parser supports common metadata but is not a comprehensive namespace-aware parser.
- User-defined arbitrary RSS feeds are not enabled in v1: source inventory uses a reviewed built-in list.
- No downloading or caching of third-party images; decorative UI uses native colors only.
- Saved items are metadata cached at the time of fetching, not offline full articles.
- The exact user's approved original mascot asset still needs review before publication.
