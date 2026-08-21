# OpenPianos — Dataset

The open dataset of the world's public pianos, published as versioned exports.
This repository is the **public mirror** of the canonical OpenPianos database —
per the founding brief, it exists so the data stays accessible independently of
any application, server, or frontend.

```
latest/       pianos.json · pianos.geojson · pianos.csv  (current canonical set)
snapshots/    dated folders — the dataset as of that day
schema/       the data model behind the exports
```

Exports are published automatically (pipeline being wired up — see
[site#2](https://github.com/OpenPianos/site/issues/2)). Until the first export
lands, `latest/` is empty.

## License

The OpenPianos dataset is public domain — [CC0 1.0](LICENSE). Attribution is
requested as a community norm, not a legal requirement.

Records imported from sources with their own licenses (e.g. OpenStreetMap,
ODbL) are marked with their source and carried under that source's terms — they
are attributed and are **not** relabeled CC0. Per-source licensing is
documented in the [spec's source registry](https://github.com/OpenPianos/spec/blob/master/SOURCES.md).

## More

- Data model & governance: [OpenPianos/spec](https://github.com/OpenPianos/spec)
- The map & wiki: [openpianos.net](https://openpianos.net)
