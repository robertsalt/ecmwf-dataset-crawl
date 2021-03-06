name: "crawler"

includes:
    - resource: true
      file: "/crawler-default.yaml"
      override: false

    - resource: false
      file: "crawler-conf.flux"
      override: true

    - resource: false
      file: "es-conf.flux"
      override: true

spouts:
  - id: "spout"
    className: "org.n52.webcrawl.CollapsingSpout"
    parallelism: 10

bolts:
  - id: "partitioner"
    className: "com.digitalpebble.stormcrawler.bolt.URLPartitionerBolt"
    parallelism: 1
  - id: "fetcher"
    className: "com.digitalpebble.stormcrawler.bolt.FetcherBolt"
    parallelism: 1
  - id: "sitemap"
    className: "com.digitalpebble.stormcrawler.bolt.SiteMapParserBolt"
    parallelism: 1
  - id: "parse"
    className: "org.n52.webcrawl.ParserBolt"
    parallelism: 5
  - id: "parsefilter"
    className: "org.n52.webcrawl.ParseFilterBolt"
    parallelism: 5
  - id: "index"
    className: "com.digitalpebble.stormcrawler.elasticsearch.bolt.IndexerBolt"
    parallelism: 1
  - id: "status"
    className: "org.n52.webcrawl.CrawlStatusUpdaterBolt"
    parallelism: 4
  - id: "status_metrics"
    className: "com.digitalpebble.stormcrawler.elasticsearch.metrics.StatusMetricsBolt"
    parallelism: 1

  - id: "languagedetect"
    className: "org.n52.webcrawl.LanguageDetectionBolt"
    parallelism: 5

  - id: "classifier_pre"
    className: "org.n52.webcrawl.MultilangPreprocessBolt"
    constructorArgs:
      - ["url", "metadata", "text", "content", "outlinks"]
    parallelism: 1
  - id: "classifier"
    className: "org.apache.storm.flux.wrappers.bolts.FluxShellBolt"
    constructorArgs:
      - ["python3", "dataset_classifier_bolt.py"]
      - ["url", "metadata", "text", "content", "outlinks"]
    parallelism: 5
  - id: "classifier_post"
    className: "org.n52.webcrawl.MultilangPostprocessBolt"
    constructorArgs:
      - ["url", "metadata", "text", "content", "outlinks"]
    parallelism: 1

  - id: "tagging"
    className: "org.n52.webcrawl.TaggingBolt"
    parallelism: 1

streams:
  - from: "spout"
    to: "partitioner"
    grouping:
      type: SHUFFLE

  - from: "spout"
    to: "status_metrics"
    grouping:
      type: SHUFFLE

  - from: "partitioner"
    to: "fetcher"
    grouping:
      type: FIELDS
      args: ["key"]

  - from: "fetcher"
    to: "sitemap"
    grouping:
      type: LOCAL_OR_SHUFFLE

  - from: "sitemap"
    to: "parse"
    grouping:
      type: LOCAL_OR_SHUFFLE

  - from: "parse"
    to: "languagedetect"
    grouping:
      type: LOCAL_OR_SHUFFLE

  - from: "languagedetect"
    to: "classifier_pre"
    grouping:
      type: LOCAL_OR_SHUFFLE

  - from: "classifier_pre"
    to: "classifier"
    grouping:
      type: LOCAL_OR_SHUFFLE

  - from: "classifier"
    to: "classifier_post"
    grouping:
      type: LOCAL_OR_SHUFFLE

  - from: "classifier_post"
    to: "parsefilter"
    grouping:
      type: LOCAL_OR_SHUFFLE

  - from: "parsefilter"
    to: "tagging"
    grouping:
      type: LOCAL_OR_SHUFFLE

  - from: "tagging"
    to: "index"
    grouping:
      type: LOCAL_OR_SHUFFLE

  - from: "fetcher"
    to: "status"
    grouping:
      type: FIELDS
      args: ["url"]
      streamId: "status"

  - from: "sitemap"
    to: "status"
    grouping:
      type: FIELDS
      args: ["url"]
      streamId: "status"

  - from: "parse"
    to: "status"
    grouping:
      type: FIELDS
      args: ["url"]
      streamId: "status"

  - from: "parsefilter"
    to: "status"
    grouping:
      type: FIELDS
      args: ["url"]
      streamId: "status"

  - from: "index"
    to: "status"
    grouping:
      type: FIELDS
      args: ["url"]
      streamId: "status"
