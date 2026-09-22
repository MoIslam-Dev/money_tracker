# Working agreements

- This project lives on GitHub: https://github.com/MoIslam-Dev/money_tracker (branch `main`).
- After every requested change (feature, fix, theme tweak, test, etc.), commit the
  work with a concise, descriptive message and push to `origin/main`.
  Example: commit once per logical change, then `git push`.
- Every change ships an installable APK: bump `version`/`versionCode` in `pubspec.yaml`,
  build a release APK (`flutter build apk --release`), upload it
  (https://files.catbox.moe is used so far), verify the upload, and give the user a
  fresh download URL to test on their phone. This is mandatory for all changes.
- Keep build artifacts out of commits (`/build`, `.dart_tool`, `.idea` are gitignored).
- Never commit secrets or keystores (this repo is public).
- Test commands (Linux env):
  `ln -sf /lib/x86_64-linux-gnu/libsqlite3.so.0.8.6 $HOME/.local/lib/libsqlite3.so`
  `LD_LIBRARY_PATH=$HOME/.local/lib flutter test`