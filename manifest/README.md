IPvFoo uses a different manifest.json file for Chrome vs. Firefox.
One must be copied to the parent directory:

```
cp firefox-manifest.json ../src/manifest.json
cp chrome-manifest.json ../src/manifest.json
```
