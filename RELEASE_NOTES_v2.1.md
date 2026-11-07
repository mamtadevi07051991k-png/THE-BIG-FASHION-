# THE BIG FASHION Customer App — Update 2.1

- Home now loads the complete active Supabase catalog, newest first, and separates Trending, Men, Women, and other categories.
- Catalog data is cached locally for faster repeat opens; the live catalog refresh runs without blocking the first screen.
- The startup splash is shortened to reduce perceived waiting time.
- Tracking timeline marks all completed stages blue and the current stage amber.
- Supabase client scripts are deferred so the initial page can paint sooner.

No new SQL migration is required for these UI/performance changes. The previously run customer sync migration remains required.
