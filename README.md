# How to use Connectware with Fluent Bit and Grafana Loki

This is an example how to configure a Connectware Docker composition 
for use with a Fluent-Bit log shipping to a Grafana Loki instance.

A variant for the Connectware Kubernetes deployment is not part of this document.

## Objective

The goal is to replace a default per-container json logging with a fast and easy log aggregation 
for Cybus Connectware with low impact on processing, forwarding, visualization and setup effort,
so that logs can be easier processed (analyzed, correlated, stored).

## Stdout Shortcut

To simply stream the container logs out of the composition:
- first change the Docker log driver to `fluentd`,
- then start a fluent-bit instance like below and
- finally start the Connectware Docker composition.

> ℹ️ Make sure to use a valid Connectware License key in the `.env` file.

```
docker run --rm -p 127.0.0.1:24224:24224 --name fluent-bit \
    fluent/fluent-bit:1.9.7 /fluent-bit/bin/fluent-bit \
    -i forward -o stdout -p format=json_lines -f 1
```

### Reconfigure the Connectware docker composition

The default logging driver used with the Connectware Docker composition is `json-file`
due to some insights about most useful default medium requirements.
It's up to the Connectware operator to change this for other requirements.

This is configured on per-container basis like this:
```
  logging:
    driver: json-file
    options:
      max-file: "2"
      max-size: 10m
```

Every container can be configured individually for logging, so that the user can decide,
which logs should reach the configured container.

The above log configuration can be replaced with the fluentd variant:
```
  logging:
    driver: fluentd
    options:
      fluentd-address: "tcp://fluentdhost:24224"
      fluentd-async: "true"
      fluentd-sub-second-precision: "true"
```

Start the Connectware with one or more of these replacements
and see the log output in the running fluent-bit container.


## Centralized Log configuration in Connectware

To simplify the log configuration, a user can utilize
- extension fields in docker compositions (since version 3.4, [Docker Compose Extension Fields](https://docs.docker.com/compose/compose-file/compose-file-v3/#extension-fields)
- Yaml anchors and aliases together with the merge key  

The extension field is marked with an anchor `logging`:
```
x-logging: &logging
  logging:
    driver: fluentd
    options:
      fluentd-address: "tcp://fluentdhost:24224"
      fluentd-async: "true"
      fluentd-sub-second-precision: "true"
...      
```

Now every service specific logging object in the compose file can be replaced like this:
```
...
services:
  admin-web-app:
...
    image: registry.cybus.io/cybus/admin-web-app:1.0.91
    labels:
    - io.cybus.connectware=core
    <<: *logging
...
  auth-server:
...
    image: registry.cybus.io/cybus/auth-server:1.0.91
    labels:
    - io.cybus.connectware=core
    <<: *logging
...
```

Start the Connectware with the complete replacement 
and see all Connectware logs in the running fluent-bit container.


## Forward logs to Grafana Loki using Fluent-Bit

### Quickstart

Using the docker compositions in this production start the solution in 3 lines
including Connectware:

```
docker compose -f docker-compose-loki.yml up -d
docker compose -f docker-comopose-fluentbit.yml up -d
cd connectware && docker compose -f docker-compose_alias_logging_fluentbit.yml
```

Open a browser window, visit `http://localhost:3000` for the Grafana Frontend,
finish the admin setup and select the explorer view.

Use a container from the log-label and query the Connectware Logs.

See the [Grafana Loki Example for the Connectware Protocol Mapper Container](./grafana-loki-explore-connectware-protocol-mapper.png)

### Details

To forward the logs to one or many higher-level tools ([Fluent-Bit Outputs](https://docs.fluentbit.io/manual/pipeline/outputs)) 
like Loki, Elasticsearch, Kafka, InfluxDB and others, the operator needs to configure
fluent-bit accordingly.

In this example we focus on a lightweight approach with a Grafana Loki instance
as some "sidecar" composition alongside the running Connectware.

See the [Grafana Loki composition](./docker-compose-loki.yml) for an example
how to provide a simple output endpoint for Fluent-Bit.

A local configuration [loki.yml sample](./configs/loki/loki.yaml) shows some basic
settings to work with. For production use like for a useful retention period etc.
follow the [Loki configuration docs](https://grafana.com/docs/loki/latest/configuration/).

Grafana is set up for [Loki as a data source](./configs/grafana/datasource.yaml) 
without further settings

Finally, the [Fluent-Bit composition](./docker-compose-fluentbit.yml) uses a 
Grafana Fluent Bit container image with the Loki output plugin pre-installed 
with a [simplified configuration sample](./configs/fluentbit/fluent-bit.conf) 
to connect to Loki.

## Next steps

The Fluent-Bit instance can easily be configured for further/parallel outputs
and more complex configuration e.g. for more useful labels.
See the corresponding documentation.

The CPU and memory footprint is pretty small, so further measures to tweak
the setup for production use may be just need for massive load and contraints
in the environment.

Loki as the log aggregator has many option to work with, especially a retention
period will be for useful for stable production use. Whether the storage needs
more attention or not, will depend on the operational requirements.

Grafana as a widely used frontend is useful for many aspects. 
The typical log queries for correlation between the different containers
are proper for debugging and QA.

Grafana as an observability platform can be enriched with further data sources
for monitoring and metrics, alerts and not least for graphical visualization.


## References

- [Cybus Connectware](https://cybus.io)
- [Fluent Bit](https://fluentbit.io)
- [Docker logging drivers](https://docs.docker.com/config/containers/logging/configure/#supported-logging-drivers)
- [Docker Compose Extension Fields](https://docs.docker.com/compose/compose-file/compose-file-v3/#extension-fields)
- [Grafana Loki](https://grafana.com/oss/loki)
- [Fluent-Bit Outputs](https://docs.fluentbit.io/manual/pipeline/outputs)
- [Fluentd vs Fluent Bit](https://logz.io/blog/fluentd-vs-fluent-bit/)
