# WikiTrans Dictionary - Bilingual Wikipedia Search

Fast auto-complete style dictionary translation for English, Japanese, Chinese, Korean, French, Spanish and German.

<a href="https://twitter.com/arex"><img src="https://img.shields.io/twitter/follow/arex" alt="Follow @arex"></a>
  [Postmeta.com](https://postmeta.com)

### Features

- Quickly find that movie title in Japanese or your favourite actor’s name in Chinese
- Compare both Wikipedia pages on one screen
- Over 11.7million+ words and phrases
  
<img src="https://raw.githubusercontent.com/areyasouka/wikitrans/main/docs/screenshot.png" alt="Screenshot showing iPhone WikiTrans App" title="iPhone WikiTrans App screenshot" width="640">

### Dependencies

- Xcode
- sqlite
- python

### Build

```sh
# build with Xcode
```

### Generate Dictionary SQLite Data (optional)

```sh
# download wikidata
# ~5.5hrs to download 80gb compressed
wget https://dumps.wikimedia.org/wikidatawiki/entities/latest-all.json.gz -P ./data

./util/builddb.sh
```

## TODO

- automate database build, dump to s3

